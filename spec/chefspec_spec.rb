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

require 'spec_helper'

describe PoiseSpec::ChefSpec do
  include described_class

  describe '#recipe' do
    context 'with a block' do
      recipe do
        ruby_block 'test'
      end

      it { is_expected.to run_ruby_block('test') }
    end # /context with a block

    context 'with a recipe' do
      let(:chefspec_options) { {dry_run: true} }
      recipe 'test'

      it do
        expect(chef_runner).to receive(:converge).with('test')
        chef_run
      end
    end # /context with a recipe

    context 'with subject:false' do
      subject { 42 }
      recipe(subject: false) do
        ruby_block 'test'
      end

      it { is_expected.to eq 42 }
    end # /context with subject:false
  end # /describe #recipe

  describe '#resource' do
    subject { resource(:poise_test) }

    context 'with defaults' do
      resource(:poise_test)
      it { is_expected.to be_a(Class) }
      it { is_expected.to be < Chef::Resource }
      its(:resource_name) { is_expected.to eq :poise_test } if defined?(Chef::Resource.resource_name)
      it { expect(subject.new(nil, nil).resource_name).to eq(:poise_test) }
      it { expect(Array(subject.new(nil, nil).action)).to eq([:run]) }
      it { expect(subject.new(nil, nil).allowed_actions).to eq([:nothing, :run]) }
    end # /context with defaults

    context 'with auto:false' do
      resource(:poise_test, auto: false)
      it { is_expected.to be_a(Class) }
      it { is_expected.to be < Chef::Resource }
      # #resource_name was added upstream in 12.4 so ignore this test there.
      it { expect(subject.new(nil, nil).resource_name).to be_nil } unless defined?(Chef::Resource.resource_name)
      it { expect(Array(subject.new(nil, nil).action)).to eq [:nothing] }
      it { expect(subject.new(nil, nil).allowed_actions).to eq [:nothing] }
    end # /context with auto:false

    context 'with a parent' do
      resource(:poise_test, parent: Chef::Resource::File)
      it { is_expected.to be_a(Class) }
      it { is_expected.to be < Chef::Resource }
      it { is_expected.to be < Chef::Resource::File }
      its(:resource_name) { is_expected.to eq :poise_test } if defined?(Chef::Resource.resource_name)
      it { expect(subject.new(nil, nil).resource_name).to eq(:poise_test) }
    end # /context with a parent

    context 'with a helper-defined parent' do
      resource(:poise_parent)
      resource(:poise_test, parent: :poise_parent)
      it { is_expected.to be_a(Class) }
      it { is_expected.to be < Chef::Resource }
      it { is_expected.to be < Chef::Resource::PoiseParent }
      its(:resource_name) { is_expected.to eq :poise_test } if defined?(Chef::Resource.resource_name)
      it { expect(subject.new(nil, nil).resource_name).to eq(:poise_test) }
    end # /context with a helper-defined parent

    context 'with a helper-defined parent in an enclosing context' do
      resource(:poise_parent)
      context 'inner' do
        resource(:poise_test, parent: :poise_parent)
        it { is_expected.to be_a(Class) }
        it { is_expected.to be < Chef::Resource }
        it { is_expected.to be < resource(:poise_parent) }
      end
    end # /context with a helper-defined parent in an enclosing context

    # Long name is long but ¯\_(ツ)_/¯
    context 'regression test for finding the wrong parent in a sibling context' do
      resource(:poise_parent) do
        def value
          :parent
        end
      end
      subject { resource(:poise_test).new(nil, nil).value }

      context 'sibling' do
        resource(:poise_parent) do
          def value
            :sibling
          end
        end
        # Sanity check that this still works. Important test is below.
        resource(:poise_test, parent: :poise_parent)
        it { is_expected.to eq(:sibling) }
      end

      context 'inner' do
        # The actual regression test.
        resource(:poise_test, parent: :poise_parent)
        it { is_expected.to eq(:parent) }
      end
    end # /context regression test for finding the wrong parent in a sibling context

    context 'with step_into:false' do
      resource(:poise_test, step_into: false)
      provider(:poise_test) do
        def action_run
          ruby_block 'inner'
        end
      end
      recipe do
        poise_test 'test'
      end
      # Have to create this because step_into normally handles that
      def run_poise_test(resource_name)
        ChefSpec::Matchers::ResourceMatcher.new(:poise_test, :run, resource_name)
      end

      it { is_expected.to run_poise_test('test') }
      it { is_expected.to_not run_ruby_block('inner') }
    end # /context with step_into:false

    describe 'with magic helpers' do
      resource(:poise_test)

      context 'on the class' do
        its(:example_group) { is_expected.to be_truthy }
        its(:described_class) { is_expected.to eq PoiseSpec::ChefSpec }
      end # /context on the class

      context 'on the instance' do
        subject { super().new(nil, nil) }
        its(:example_group) { is_expected.to be_truthy }
        its(:described_class) { is_expected.to eq PoiseSpec::ChefSpec }
      end # /context on the instance
    end # /describe with magic helpers
  end # /describe #resource

  describe '#provider' do
    subject { provider(:poise_test) }

    context 'with defaults' do
      provider(:poise_test)
      it { is_expected.to be_a(Class) }
      it { is_expected.to be < Chef::Provider }
      its(:instance_methods) { are_expected.to include(:action_run) }
    end # /context with defaults

    context 'with magic helpers' do
      provider(:poise_test)

      context 'on the class' do
        its(:example_group) { is_expected.to be_truthy }
        its(:described_class) { is_expected.to eq PoiseSpec::ChefSpec }
      end # /context on the class

      context 'on the instance' do
        subject { super().new(nil, nil) }
        its(:example_group) { is_expected.to be_truthy }
        its(:described_class) { is_expected.to eq PoiseSpec::ChefSpec }
      end # /context on the instance
    end # /describe with magic helpers
  end # /describe #provider

  describe '#step_into' do
    context 'with a simple HWRP' do
      recipe do
        poise_test_simple 'test'
      end

      context 'with step_into' do
        step_into(:poise_test_simple)
        it { is_expected.to run_poise_test_simple('test') }
        it { is_expected.to run_ruby_block('test') }
        it { expect(chef_run.poise_test_simple('test')).to be_a(Chef::Resource) }
      end # /context with step_into

      context 'without step_into' do
        # Can't use the nice matcher because step_into is what would create that.
        it { is_expected.to ChefSpec::Matchers::ResourceMatcher.new('poise_test_simple', 'run', 'test') }
        it { is_expected.to_not run_ruby_block('test') }
      end # /context without step_into
    end # /context with a simple HWRP

    context 'with a Poise resource' do
      recipe do
        poise_test_poise 'test'
      end

      context 'with step_into' do
        step_into(:poise_test_poise)
        it { is_expected.to run_poise_test_poise('test') }
        it { is_expected.to run_ruby_block('test') }
        it { expect(chef_run.poise_test_poise('test')).to be_a(Chef::Resource) }
      end # /context with step_into

      context 'without step_into' do
        it { is_expected.to run_poise_test_poise('test') }
        it { is_expected.to_not run_ruby_block('test') }
        it { expect(chef_run.poise_test_poise('test')).to be_a(Chef::Resource) }
      end # /context without step_into
    end # /context with a Poise resource

    describe 'without step-into there should be no ChefSpec resource-level matcher' do
      provider(:poise_test_help)

      context 'helper-created resource' do
        resource(:poise_test_helper, step_into: false)
        recipe do
          poise_test_helper 'test'
        end
        it { expect { chef_run.poise_test_helper('test' ) }.to raise_error NoMethodError }
      end # /context helper-created resource

      context 'helper-created resource with Poise' do
        resource(:poise_test_helper_poise, step_into: false) do
          include Poise
          provides(:poise_test_helper_poise)
        end
        recipe do
          poise_test_helper_poise 'test'
        end
        it { expect(chef_run.poise_test_helper_poise('test' )).to be_a(Chef::Resource) }
      end # /context helper-created resource with Poise
    end # describe without step-into there should be no ChefSpec resource-level matcher
  end # /describe #step_into

  describe 'patcher' do
    #let(:chefspec_options) { {log_level: :debug} }
    resource(:poise_test)
    subject { resource(:poise_test).new('test', chef_run.run_context).provider_for_action(:run) }

    context 'with a provider in scope' do
      provider(:poise_test)
      # Basically it just shouldn't raise an error.
      it { is_expected.to be_truthy }
    end # /context with a provider in scope

    context 'with a named provider in scope' do
      provider(:poise_test_other) do
        provides(:poise_test)
      end
      # Basically it just shouldn't raise an error.
      it { is_expected.to be_truthy }
    end # /context with a named provider in scope

    context 'without a provider in scope' do
      # 12.4.1+ uses Chef::Exceptions::ProviderNotFound, before that ArgumentError.
      it { expect { subject }.to raise_error (defined?(Chef::Exceptions::ProviderNotFound) ? Chef::Exceptions::ProviderNotFound : ArgumentError) }
    end # /context without a provider in scope
  end # /describe patcher
end
