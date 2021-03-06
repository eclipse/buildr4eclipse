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

Feature: The Eclipse instance repository

Scenario: The user should be able to specify that he is using one or more Eclipse instances from his environment variables
  Given a project identified as a plugin
  When the user uses an environment variable named BUILDR_ECLIPSE to point to one or more Eclipse instances
  Then Buildr4eclipse should be aware of the Eclipse instances defined on the user system

Scenario: The user should be able to specify that he is using one or more Eclipse instances from his Buildr settings
  Given a project identified as a plugin
  When the user defines Eclipse instances in his buildr settings under the key eclipse_instances
  Then Buildr4eclipse should be aware of the Eclipse instances defined on the user system

Scenario: Buildr4eclipse should add the missing plugins to an Eclipse instance for the purpose of developing a plugin through a task
   Given a project identified as a plugin with plugin dependencies, with at least one Eclipse instance registered
   When the user types "buildr eclipse:add_missing_dependencies ~/eclipse"
   Then the missing plugin dependencies in the Eclipse instance should be copied to the dropins folder

Scenario: Buildr4eclipse should offer a task to generate the Eclipse project files according to the buildfile
  Given a project identified as a plugin with plugin dependencies, with at least one Eclipse instance registered
  When the user types "buildr eclipse"
  Then the .classpath and .project files should be generated for the project
	