###############################################################################
# Copyright (c) 2009 Buildr4Eclipse and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#     Buildr4Eclipse - initial API and implementation
###############################################################################

# Point to the buildr source to run with Buildr's source.
require File.dirname(__FILE__) + "/../buildr/spec/spec_helpers.rb"


require 'ruby-debug'
Debugger.start


require 'lib/buildr4eclipse'
