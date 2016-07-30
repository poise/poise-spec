#
# Copyright 2016, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chefspec'
require 'rspec/core/shared_context'

require 'poise_spec/attributes'
require 'poise_spec/fauxhai'
require 'poise_spec/runner'


module PoiseSpec
  module ChefSpec
    extend RSpec::SharedContext
    include PoiseSpec::Attributes
    include PoiseSpec::Fauxhai

    # An alias for slightly more semantic meaning, just forces the lazy #subject
    # to run.
    #
    # @see http://www.relishapp.com/rspec/rspec-core/v/3-2/docs/subject/explicit-subject RSpec's subject helper
    # @example
    #   describe 'my recipe' do
    #     recipe 'my_recipe'
    #     it { run_chef }
    #   end
    def run_chef
      chef_run
    end

    # Return a helper-defined resource.
    #
    # @param name [Symbol] Name of the resource.
    # @return [Class]
    # @example
    #    subject { resource(:my_resource) }
    def resource(name)
      self.class.resources[name.to_sym]
    end

    # Return a helper-defined provider.
    #
    # @param name [Symbol] Name of the provider.
    # @return [Class]
    # @example
    #    subject { provider(:my_provider) }
    def provider(name)
      self.class.providers[name.to_sym]
    end

    # @!classmethods
    module ClassMethods
      def included(klass)
        super
        klass.extend ClassMethods

        # @!attribute [r] step_into
        #   Resource names to step in to when running this example.
        #   @see https://github.com/sethvargo/chefspec#testing-lwrps
        #   @return [Array<Symbol>]
        #   @example
        #     before do
        #       step_into << :my_lwrp
        #     end
        klass.let(:step_into) { [] }
        # @!attribute [r] chefspec_options
        #   Options hash for the ChefSpec runner instance.
        #   @return [Hash<Symbol, Object>]
        #   @example Enable Fauxhai attributes
        #     let(:chefspec_options) { {platform: 'ubuntu', version: '12.04'} }
        klass.param(:chefspec_options) { Hash.new }
        # @!attribute [r] chef_runner
        #   ChefSpec runner for this example.
        #   @return [ChefSpec::SoloRunner]
        klass.let(:chef_runner) do
          PoiseSpec::Runner.new(
            {
              step_into: step_into,
              default_attributes: default_attributes,
              normal_attributes: normal_attributes,
              override_attributes: override_attributes,
              automatic_attributes: automatic_attributes,
              platform: platform,
              version: version,
            }.merge(chefspec_options)
          )
        end
        # @!attribute [r] chef_run
        #   Trigger a Chef converge. By default no resources are converged. This is
        #   normally overwritten by the {#recipe} helper.
        #   @return [ChefSpec::SoloRunner]
        #   @see #recipe
        klass.let(:chef_run) { chef_runner.converge() }
      end

      # Define a recipe to be run via ChefSpec and used as the subject of this
      # example group. You can specify either a single recipe block or
      # one-or-more recipe names.
      #
      # @param recipe_names [Array<String>] Recipe names to converge for this test.
      # @param block [Proc] Recipe to converge for this test.
      # @param subject [Boolean] If true, this recipe should be the subject of
      #   this test.
      # @example Using a recipe block
      #   describe 'my recipe' do
      #     recipe do
      #       ruby_block 'test'
      #     end
      #     it { is_expected.to run_ruby_block('test') }
      #   end
      # @example Using external recipes
      #   describe 'my recipe' do
      #     recipe 'my_recipe'
      #     it { is_expected.to run_ruby_block('test') }
      #   end
      def recipe(*recipe_names, subject: true, &block)
        # Keep the actual logic in a let in case I want to define the subject as something else
        let(:chef_run) { chef_runner.converge(*recipe_names, &block) }
        subject { chef_run } if subject
      end

      # Configure ChefSpec to step in to a resource/provider. This will also
      # automatically create ChefSpec matchers for the resource.
      #
      # @overload step_into(name)
      #   @param name [String, Symbol] Name of the resource in snake-case.
      # @overload step_into(resource, resource_name)
      #   @param resource [Class] Resource class to step in to.
      #   @param resource_name [String, Symbol, nil] Name of the given resource in snake-case.
      # @example
      #   describe 'my_lwrp' do
      #     step_into(:my_lwrp)
      #     recipe do
      #       my_lwrp 'test'
      #     end
      #     it { is_expected.to run_ruby_block('test') }
      #   end
      def step_into(name, resource_name=nil, unwrap_notifying_block: true)
        resource_class = if name.is_a?(Class)
          name
        elsif resources[name.to_sym]
          # Handle cases where the resource has defined via a helper with
          # step_into:false but a nested example wants to step in.
          resources[name.to_sym]
        else
          # Won't see platform/os specific resources but not sure how to fix
          # that. I need the class here for the matcher creation below.
          Chef::Resource.resource_for_node(name.to_sym, Chef::Node.new)
        end
        resource_name ||= if resource_class.respond_to?(:resource_name)
          resource_class.resource_name
        else
          Chef::Mixin::ConvertToClassName.convert_to_snake_case(resource_class.name.split('::').last)
        end

        # Add a resource-level matcher to ChefSpec.
        ::ChefSpec.define_matcher(resource_name)

        # Figure out the available actions and create ChefSpec matchers.
        resource_class.new(nil, nil).allowed_actions.each do |action|
          define_method("#{action}_#{resource_name}") do |instance_name|
            ::ChefSpec::Matchers::ResourceMatcher.new(resource_name, action, instance_name)
          end
        end

        # Patch notifying_block from Poise::Provider to just run directly.
        # This is not a great solution but it is better than nothing for right
        # now. In the future this should maybe do an internal converge but using
        # ChefSpec somehow?
        if unwrap_notifying_block
          old_provider_for_action = resource_class.instance_method(:provider_for_action)
          resource_class.send(:define_method, :provider_for_action) do |*args|
            old_provider_for_action.bind(self).call(*args).tap do |provider|
              if provider.respond_to?(:notifying_block, true)
                provider.define_singleton_method(:notifying_block) do |&block|
                  block.call
                end
              end
            end
          end
        end

        # Add to the let variable passed in to ChefSpec.
        before { step_into << resource_name }
      end

      # Define a resource class for use in an example group. By default the
      # :run action will be set as the default.
      #
      # @param name [Symbol] Name for the resource in snake-case.
      # @param options [Hash] Resource options.
      # @option options [Class, Symbol] :parent (Chef::Resource) Parent class
      #   for the resource. If a symbol is given, it corresponds to another
      #   resource defined via this helper.
      # @option options [Boolean] :auto (true) Set the resource name correctly
      #   and use :run as the default action.
      # @param block [Proc] Body of the resource class. Optional.
      # @example
      #   describe MyMixin do
      #     resource(:my_resource) do
      #       include Poise
      #       attribute(:path, kind_of: String)
      #     end
      #     provider(:my_resource)
      #     recipe do
      #       my_resource 'test' do
      #         path '/tmp'
      #       end
      #     end
      #     it { is_expected.to run_my_resource('test').with(path: '/tmp') }
      #   end
      def resource(name, auto: true, parent: Chef::Resource, step_into: true, unwrap_notifying_block: true, defined_at: caller[0], &block)
        parent = resources[parent] if parent.is_a?(Symbol)
        raise ArgumentError.new("Parent class for #{name} is not a class: #{parent.inspect}") unless parent.is_a?(Class)
        # Pull out the example group for use in the class.
        example_group = self
        # Create the resource class.
        resource_class = Class.new(parent) do
          # Make the anonymous class pretend to have a name.
          define_singleton_method(:name) do
            'Chef::Resource::' + Chef::Mixin::ConvertToClassName.convert_to_class_name(name.to_s)
          end

          # Helper for debugging, shows where the class was defined.
          define_singleton_method(:poise_spec_defined_at) do
            defined_at
          end

          # Create magic delegators for various metadata.
          {
            example_group: example_group,
            described_class: example_group.metadata[:described_class],
          }.each do |key, value|
            define_method(key) { value }
            define_singleton_method(key) { value }
          end

          # Evaluate the class body.
          class_exec(&block) if block

          # Optional initialization steps. Disable for special unicorn tests.
          if auto
            # Fill in a :run action by default.
            old_init = instance_method(:initialize)
            define_method(:initialize) do |*args|
              old_init.bind(self).call(*args)
              # Fill in the resource name because I know it, but don't
              # overwrite because a parent might have done this already.
              @resource_name = name.to_sym
              # ChefSpec doesn't seem to work well with action :nothing
              if Array(@action) == [:nothing]
                @action = :run
                @allowed_actions |= [:run]
              end
              if defined?(self.class.default_action) && Array(self.class.default_action) == [:nothing]
                self.class.default_action(:run)
              end
            end
          end
        end

        # Try to set the resource name for 12.4+.
        if defined?(resource_class.resource_name)
          resource_class.resource_name(name)
        end

        # Clean up any global registration that happens on class compile.
        Patcher.post_create_cleanup(name, resource_class)

        # Store for use up with the parent system
        poise_spec_helpers[:resources][name.to_sym] = resource_class

        # Automatically step in to our new resource
        step_into(resource_class, name, unwrap_notifying_block: unwrap_notifying_block) if step_into

        around do |ex|
          if resource(name) == resource_class
            # We haven't been overridden from a nested scope.
            Patcher.patch(name, resource_class, Chef::Resource) { ex.run }
          else
            ex.run
          end
        end
      end

      # Define a provider class for use in an example group. By default a :run
      # action will be created, load_current_resource will be defined as a
      # no-op, and the RSpec matchers will be available inside the provider.
      #
      # @param name [Symbol] Name for the provider in snake-case.
      # @param options [Hash] Provider options.
      # @option options [Class, Symbol] :parent (Chef::Provider) Parent class
      #   for the provider. If a symbol is given, it corresponds to another
      #   resource defined via this helper.
      # @option options [Boolean] :auto (true) Create action_run and
      #   load_current_resource.
      # @option options [Boolean] :rspec (true) Include RSpec matchers in the
      #   provider.
      # @param block [Proc] Body of the provider class. Optional.
      # @example
      #   describe MyMixin do
      #     resource(:my_resource)
      #     provider(:my_resource) do
      #       include Poise
      #       def action_run
      #         ruby_block 'test'
      #       end
      #     end
      #     recipe do
      #       my_resource 'test'
      #     end
      #     it { is_expected.to run_my_resource('test') }
      #     it { is_expected.to run_ruby_block('test') }
      #   end
      def provider(name, auto: true, rspec: true, parent: Chef::Provider, defined_at: caller[0], &block)
        parent = providers[parent] if parent.is_a?(Symbol)
        raise ArgumentError.new("Parent class for #{name} is not a class: #{options[:parent].inspect}") unless parent.is_a?(Class)
        # Pull out the example group for use in the class.
        example_group = self
        # Create the provider class.
        provider_class = Class.new(parent) do
          # Pull in RSpec expectations.
          if rspec
            include RSpec::Matchers
            include RSpec::Mocks::ExampleMethods
          end

          if auto
            # Default blank impl to avoid error.
            def load_current_resource
            end

            # Blank action because I do that so much.
            def action_run
            end
          end

          # Make the anonymous class pretend to have a name.
          define_singleton_method(:name) do
            'Chef::Provider::' + Chef::Mixin::ConvertToClassName.convert_to_class_name(name.to_s)
          end

          # Helper for debugging, shows where the class was defined.
          define_singleton_method(:poise_spec_defined_at) do
            defined_at
          end

          # Create magic delegators for various metadata.
          {
            example_group: example_group,
            described_class: example_group.metadata[:described_class],
          }.each do |key, value|
            define_method(key) { value }
            define_singleton_method(key) { value }
          end

          # Evaluate the class body.
          class_exec(&block) if block
        end

        # Clean up any global registration that happens on class compile.
        Patcher.post_create_cleanup(name, provider_class)

        # Store for use up with the parent system
        poise_spec_helpers[:providers][name.to_sym] = provider_class

        around do |ex|
          if provider(name) == provider_class
            # We haven't been overridden from a nested scope.
            Patcher.patch(name, provider_class, Chef::Provider) { ex.run }
          else
            ex.run
          end
        end
      end


      # Storage for helper-defined resources and providers to find them for
      # parent lookups if needed.
      #
      # @api private
      # @return [Hash<Symbol, Hash<Symbol, Class>>]
      def poise_spec_helpers
        @poise_spec_helpers ||= {resources: {}, providers: {}}
      end

      # Find all helper-defined resources in the current context and parents.
      #
      # @api private
      # @return [Hash<Symbol, Class>]
      def resources
        ([self] + parent_groups).reverse.inject({}) do |memo, group|
          begin
            memo.merge(group.poise_spec_helpers[:resources] || {})
          rescue NoMethodError
            memo
          end
        end
      end

      # Find all helper-defined providers in the current context and parents.
      #
      # @api private
      # @return [Hash<Symbol, Class>]
      def providers
        ([self] + parent_groups).reverse.inject({}) do |memo, group|
          begin
            memo.merge(group.poise_spec_helpers[:providers] || {})
          rescue NoMethodError
            memo
          end
        end
      end
    end

    extend ClassMethods
  end
end
