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

describe PoiseSpec::Fauxhai do
  include described_class
  subject { [platform, version] }

  context 'with a platform and version' do
    platform 'centos'
    version '7.0'
    it { is_expected.to eq ['centos', '7.0'] }
  end # /context with a platform and version

  context 'with a platform (version autodetect)' do
    context 'centos' do
      platform 'centos'
      it { is_expected.to eq ['centos', '7.2.1511'] }
    end

    context 'debian' do
      platform 'debian'
      it { is_expected.to eq ['debian', '8.5'] }
    end

    context 'windows' do
      platform 'windows'
      it { is_expected.to eq ['windows', '2012R2'] }
    end
  end # /context with a platform (version autodetect)

  context 'with no platform' do
    it { is_expected.to eq ['chefspec', '0.6.1'] }
  end # /context with no platform

  context 'with an empty platform' do
    platform ''
    it { is_expected.to eq ['', ''] }
  end # /context with an empty platform
end
