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

require 'chef/resource'
require 'chef/provider'


# A `poise_test_simple` resource for use in PoiseSpec's unit tests.
class Chef
  class Resource::PoiseTestSimple < Resource
    provides(:poise_test_simple) # For Chef >= 12.4

    def initialize(*args)
      super
      @resource_name = :poise_test_simple
      @action = :run
      @allowed_actions << :run
    end
  end

  class Provider::PoiseTestSimple < Provider
    include Chef::DSL::Recipe

    provides(:poise_test_simple) # For Chef >= 12.4

    def load_current_resource
    end

    def action_run
      ruby_block new_resource.name do
        block { }
      end
    end
  end
end
