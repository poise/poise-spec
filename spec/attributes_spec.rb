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

require 'spec_helper'

describe PoiseSpec::Attributes do
  include described_class

  context 'with a single context' do
    default_attributes['foo'] = 'bar'
    it { expect(default_attributes).to eq({'foo' => 'bar'}) }
  end # /context with a single context

  context 'with a nested context' do
    default_attributes['foo'] = 'bar'
    context 'inner' do
      default_attributes['other'] = 'baz'
      it { expect(default_attributes).to eq({'foo' => 'bar', 'other' => 'baz'}) }
    end
  end # /context with a nested context

  context 'with a shadowed value' do
    default_attributes['foo'] = 'bar'
    context 'inner' do
      default_attributes['foo'] = 'baz'
      it { expect(default_attributes).to eq({'foo' => 'baz'}) }
    end
    it { expect(default_attributes).to eq({'foo' => 'bar'}) }
  end # /context with a shadowed value

  context 'with deeply nested values' do
    context 'with a single context' do
      default_attributes['testing']['foo'] = 'bar'
      it { expect(default_attributes).to eq({'testing' => {'foo' => 'bar'}}) }
    end # /context with a single context

    context 'with a nested context' do
      default_attributes['testing']['foo'] = 'bar'
      context 'inner' do
        default_attributes['testing']['other'] = 'baz'
        default_attributes['other']['nested'] = 'asdf'
        it { expect(default_attributes).to eq({'testing' => {'foo' => 'bar', 'other' => 'baz'}, 'other' => {'nested' => 'asdf'}}) }
      end
    end # /context with a nested context

    context 'with a shadowed value' do
      default_attributes['testing']['foo'] = 'bar'
      context 'inner' do
        default_attributes['testing']['foo'] = 'baz'
        it { expect(default_attributes).to eq({'testing' => {'foo' => 'baz'}}) }
      end
      it { expect(default_attributes).to eq({'testing' => {'foo' => 'bar'}}) }
    end # /context with a shadowed value
  end # /context with deeply nested values

  context 'with short default helper' do
    default['foo'] = 'bar'
    it { expect(default_attributes).to eq({'foo' => 'bar'}) }
  end # /context with short default helper

  context 'with normal level' do
    context 'with long method' do
      normal_attributes['foo'] = 'bar'
      it { expect(normal_attributes).to eq({'foo' => 'bar'}) }
    end # /context with long method

    context 'with short method' do
      normal['foo'] = 'bar'
      it { expect(normal_attributes).to eq({'foo' => 'bar'}) }
    end # /context with short method
  end # /context with normal level

  context 'with override level' do
    context 'with long method' do
      override_attributes['foo'] = 'bar'
      it { expect(override_attributes).to eq({'foo' => 'bar'}) }
    end # /context with long method

    context 'with short method' do
      override['foo'] = 'bar'
      it { expect(override_attributes).to eq({'foo' => 'bar'}) }
    end # /context with short method
  end # /context with override level

  context 'with automatic level' do
    context 'with long method' do
      automatic_attributes['foo'] = 'bar'
      it { expect(automatic_attributes).to eq({'foo' => 'bar'}) }
    end # /context with long method

    context 'with short method' do
      automatic['foo'] = 'bar'
      it { expect(automatic_attributes).to eq({'foo' => 'bar'}) }
    end # /context with short method
  end # /context with automatic level
end
