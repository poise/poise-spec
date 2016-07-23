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

require 'chef/mash' # Needed for chef/node/attribute.
require 'chef/node/attribute'

require 'poise_spec/utils'


module PoiseSpec
  module Attributes
    extend RSpec::SharedContext

    let(:default_attributes) { self.class.default_attributes }
    let(:normal_attributes) { self.class.normal_attributes }
    let(:override_attributes) { self.class.override_attributes }
    let(:automatic_attributes) { self.class.automatic_attributes }

    module ClassMethods
      def node_attributes
        @node_attributes ||= if self.superclass && self.superclass.respond_to?(:node_attributes)
          # Clone from the parent context as a base.
          base = self.superclass.node_attributes
          Chef::Node::Attribute.new(PoiseSpec::Utils.deep_dup(base.normal),
                                    PoiseSpec::Utils.deep_dup(base.default),
                                    PoiseSpec::Utils.deep_dup(base.override),
                                    PoiseSpec::Utils.deep_dup(base.automatic))
        else
          # Top-level context
         Chef::Node::Attribute.new({}, {}, {}, {})
        end
      end

      def default_attributes
        node_attributes.default
      end

      alias_method :default, :default_attributes

      def normal_attributes
        node_attributes.normal
      end

      alias_method :normal, :normal_attributes

      def override_attributes
        node_attributes.override
      end

      alias_method :override, :override_attributes

      def automatic_attributes
        node_attributes.automatic
      end

      alias_method :automatic, :automatic_attributes

      def included(klass)
        super
        klass.extend ClassMethods
      end
    end

    extend ClassMethods
  end
end
