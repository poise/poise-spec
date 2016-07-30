#
# Copyright 2015-2016, Noah Kantrowitz
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

require 'chef/mixin/shell_out' # ಠ_ಠ Missing upstream require
require 'chef/recipe'
require 'chefspec/mixins/normalize' # ಠ_ಠ Missing upstream require
require 'chefspec/solo_runner'


module PoiseSpec
  # ChefSpec runner class with PoiseSpec customizations. This adds attribute
  # options, Halite synthetic cookbook injection, and block-based recipes.
  #
  # @since 1.0.0
  class Runner < ChefSpec::SoloRunner
    # Override base class .converge to support block arguments too.
    #
    # @see #converge
    # @param params [Array] Array of parameters to pass to {#converge}.
    # @param options [Hash] Hash of options to pass to the constructor.
    # @param block [Proc] Optional recipe block to converge.
    # @return [PoiseSpec::Runner]
    def self.converge(*params, **options, &block)
      new(options).tap do |instance|
        instance.converge(*params, &block)
      end
    end

    # Create a new Runner instance.
    #
    # @param default_attributes [Hash] Extra default attributes to set.
    # @param normal_attributes [Hash] Extra normal attributes to set.
    # @param override_attributes [Hash] Extra override attributes to set.
    # @param automatic_attributes [Hash] Extra automatic attributes to set.
    # @param options [Hash] Extra options to pass through to
    #   ChefSpec::SoloRunner#converge
    def initialize(default_attributes: nil, normal_attributes: nil, override_attributes: nil, automatic_attributes: nil, **options)
      super(options) do |node|
        # Allow inserting arbitrary attribute data in to the node
        node.attributes.default = Chef::Mixin::DeepMerge.merge(node.attributes.default, default_attributes) if default_attributes
        node.attributes.normal = Chef::Mixin::DeepMerge.merge(node.attributes.normal, normal_attributes) if normal_attributes
        node.attributes.override = Chef::Mixin::DeepMerge.merge(node.attributes.override, override_attributes) if override_attributes
        node.attributes.automatic = Chef::Mixin::DeepMerge.merge(node.attributes.automatic, automatic_attributes) if automatic_attributes
      end
    end

    # Converge a recipes either via normal run list or a block.
    #
    # @param recipe_names [Array<String>] Run list to converge.
    # @param block [Proc] Block of recipe code to converge.
    # @return [void]
    def converge(*recipe_names, &block)
      raise ArgumentError.new('Cannot pass both recipe names and a recipe block to converge') if !recipe_names.empty? && block
      super(*recipe_names) do
        if block
          recipe = Chef::Recipe.new(nil, nil, self.run_context)
          recipe.instance_exec(&block)
        end
      end
    end

    private

    # Don't try to autodetect the calling cookbook. This is overriding an
    # internal method from the base class and may be fragile.
    #
    # @api private
    def calling_cookbook_path(_kaller)
      # Pretend the calling cookbook is an empty folder so it won't use it.
      File.expand_path('../empty', __FILE__)
    end
  end
end
