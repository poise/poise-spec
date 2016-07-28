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

require 'fauxhai'
require 'rspec-param'


module PoiseSpec
  module Fauxhai
    def self.included(klass)
      super
      klass.include RSpecParam

      klass.param(:platform, 'chefspec')

      klass.param(:version) do
        # In case it gets set to nil or '' somehow.
        return unless platform || platform.empty?
        # Find the path to the platform JSON files.
        json_path = File.expand_path("lib/fauxhai/platforms/#{platform}/*.json", ::Fauxhai.root)
        # Get a list of all versions.
        versions = Dir[json_path].map {|path| File.basename(path, '.json') }
        # Take the highest version available. Treat R like a separator.
        versions.max_by {|ver| Gem::Version.create(ver.gsub(/r/i, '.')) }
      end

    end
  end
end
