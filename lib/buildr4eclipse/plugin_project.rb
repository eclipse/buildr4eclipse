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

require "manifest"

module Buildr4Eclipse #:nodoc:
  

  # A module that to add to the Buildr::Project class
  # Projects with that module include can identify themselves as eclipse projects
  module EclipseProject

    def project_id
      name.split(':').last
    end
    
    def version
      raise 'Subclasses must implement'
    end

  end


  # A module to add to the Buildr::Project class
  # Projects with that module included can auto-resolve their dependencies
  module PluginProject
    
    include EclipseProject

    ECLIPSE_GROUP_ID = "__eclipse"
    
    B_NAME = "Bundle-SymbolicName"
    B_REQUIRE = "Require-Bundle"
    B_VERSION = "Bundle-Version"
    B_DEP_VERSION = "bundle-version"
    B_RESOLUTION = "resolution"
    B_LAZY_START = "Bundle-ActivationPolicy"
    B_OLD_LAZY_START = "Eclipse-LazyStart"
    
    attr_accessor :groupId
    
    # returns an array of the dependencies of the plugin, read from the manifest.
    def autoresolve(add_optionals = true)
      return [] unless File.exists?(manifest_file_path)
      manifest = Manifest.read(manifest_file_contents)
      bundles = []
      manifest.first[B_REQUIRE].each_pair {|key, value| bundles << "#{determine_group_id(key.strip)}:#{key.strip}:#{value[B_DEP_VERSION]}" unless "system.bundle" == key || (value[B_RESOLUTION] == "optional" && !add_optionals)} unless manifest.first[B_REQUIRE].nil?
      bundles
    end
    
    def version
      manifest.main["Bundle-Version"]
    end

    def manifest
      manifest = Buildr::Packaging::Java::Manifest.parse(File.read(manifest_file_path))
    end
    
    # overrides project's layout to provide a plugin layout
    def layout
      @layout ||= (parent ? parent.layout : Layout.plugin_default).clone
    end
    
    private 
    
    def manifest_file_path
      File.expand_path("#{project_id}/META-INF/MANIFEST.MF")
    end

    def manifest_file_contents
      if File.exists?(manifest_file_path) then
        File.read(manifest_file_path)
      else
        ""
      end
    end

    # Artifacts that are resolved as dependencies from a manifest don't have a group id. We do the mapping in there.
    def determine_group_id(artifactId)
      return @groupId ? @groupId.call(artifactId) : ECLIPSE_GROUP_ID
    end
    
  end

  module PluginProjectHook
      include Buildr::Extension

      def act_as_eclipse_plugin
        extend Buildr4Eclipse::PluginProject
        @layout=Buildr::Layout::PluginLayout.new(project_id)
      end

  end
end

class Buildr::Project
  include Buildr4Eclipse::PluginProjectHook
end
