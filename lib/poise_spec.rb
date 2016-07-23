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


# An RSpec helper module for writing unit tests for library-oriented Chef cookbooks.
#
# @since 1.0.0
module PoiseSpec
  autoload :Attributes, 'poise_spec/attributes'

  module ClassMethods

    def included(klass)
      super
      klass.extend ClassMethods
    end
  end

  extend ClassMethods
end
