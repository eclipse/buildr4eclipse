# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.


require 'buildr/java'


module Buildr

  # Provides the <code>cobertura:html</code> and <code>cobertura:xml</code> tasks.
  # Require explicitly using <code>require "buildr/cobertura"</code>.
  #
  # You can generate cobertura reports for a single project 
  # using the project name as prefix:
  #
  #   project_name:cobertura:html
  #
  # You can also specify which classes to include/exclude from instrumentation by 
  # passing a class name regexp to the <code>cobertura.include</code> or 
  # <code>cobertura.exclude</code> methods. 
  # 
  #   define 'someModule' do 
  #      cobertura.include 'some.package.*'
  #      cobertura.include /some.(foo|bar).*/
  #      cobertura.exclude 'some.foo.util.SimpleUtil'
  #      cobertura.exclude /*.Const(ants)?/i
  #   end
  module Cobertura

    class << self

      REQUIRES = ["net.sourceforge.cobertura:cobertura:jar:1.9", "log4j:log4j:jar:1.2.9",
        "asm:asm:jar:2.2.1", "asm:asm-tree:jar:2.2.1", "oro:oro:jar:2.0.8"] unless const_defined?('REQUIRES')

      def requires()
        @requires ||= Buildr.artifacts(REQUIRES).each(&:invoke).map(&:to_s)
      end

      def report_to(file = nil)
        File.expand_path(File.join(*["reports/cobertura", file.to_s].compact))
      end

      def data_file()
        File.expand_path("reports/cobertura.ser")
      end

    end
    
    class CoberturaConfig # :nodoc:
      
      def initialize(project)
        @project = project
      end
      
      attr_reader :project
      private :project

      attr_writer :data_file, :instrumented_dir, :report_dir
      
      def data_file
        @data_file ||= project.path_to(:reports, 'cobertura.ser')
      end

      def instrumented_dir
        @instrumented_dir ||= project.path_to(:target, :instrumented, :classes)
      end

      def report_dir
        @report_dir ||= project.path_to(:reports, :cobertura)
      end

      def report_to(file = nil)
        File.expand_path(File.join(*[report_dir, file.to_s].compact))
      end

      # :call-seq:
      #   project.cobertura.include(*classPatterns)
      #
      def include(*classPatterns)
        includes.push(*classPatterns.map { |p| String === p ? Regexp.new(p) : p })
        self
      end
      
      def includes
        @includeClasses ||= []
      end

      # :call-seq:
      #   project.cobertura.exclude(*classPatterns)
      #
      def exclude(*classPatterns)
        excludes.push(*classPatterns.map { |p| String === p ? Regexp.new(p) : p })
        self
      end

      def excludes
        @excludeClasses ||= []
      end

      def sources
        project.compile.sources
      end
    end

    module CoberturaExtension # :nodoc:
      include Buildr::Extension

      def cobertura
        @cobertura_config ||= CoberturaConfig.new(self)
      end

      after_define do |project|
        cobertura = project.cobertura
        
        namespace 'cobertura' do
          unless project.compile.target.nil?
            # Instrumented bytecode goes in a different directory. This task creates before running the test
            # cases and monitors for changes in the generate bytecode.
            instrumented = project.file(cobertura.instrumented_dir => project.compile.target) do |task|
              mkdir_p task.to_s, :verbose => false
              unless project.compile.sources.empty?
                info "Instrumenting classes with cobertura data file #{cobertura.data_file}"
                Buildr.ant "cobertura" do |ant|
                  ant.taskdef :classpath=>Cobertura.requires.join(File::PATH_SEPARATOR), :resource=>"tasks.properties"
                  ant.send "cobertura-instrument", :todir=>task.to_s, :datafile=>cobertura.data_file do
                    includes, excludes = cobertura.includes, cobertura.excludes
                    
                    classes_dir = project.compile.target.to_s
                    if includes.empty? && excludes.empty? 
                      ant.fileset :dir => classes_dir do 
                        ant.include :name => "**/*.class"
                      end
                    else
                      includes = [//] if includes.empty?
                      Dir.glob(File.join(classes_dir, "**/*.class")) do |cls|
                        cls_name = cls.gsub(/#{classes_dir}\/?|\.class$/, '').gsub('/', '.')
                        if includes.any? { |p| p === cls_name } && !excludes.any? { |p| p === cls_name }
                          ant.fileset :file => cls
                        end
                      end
                    end
                  end
                end
              end
              touch task.to_s, :verbose=>false
            end
            
            task 'instrument' => instrumented
            
            # We now have two target directories with bytecode. It would make sense to remove compile.target
            # and add instrumented instead, but apparently Cobertura only creates some of the classes, so
            # we need both directories and instrumented must come first.
            project.test.dependencies.unshift cobertura.instrumented_dir
            project.test.with Cobertura.requires
            project.test.options[:properties]["net.sourceforge.cobertura.datafile"] = cobertura.data_file
            
            [:xml, :html].each do |format|
              task format => ['instrument', 'test'] do 
                info "Creating test coverage reports in #{cobertura.report_to(format)}"
                Buildr.ant "cobertura" do |ant|
                  ant.taskdef :classpath=>Cobertura.requires.join(File::PATH_SEPARATOR), :resource=>"tasks.properties"
                  ant.send "cobertura-report", :format=>format, 
                    :destdir=>cobertura.report_to(format), :datafile=>cobertura.data_file do
                    cobertura.sources.flatten.each do |src|
                      ant.fileset(:dir=>src.to_s) if File.exist?(src.to_s)
                    end
                  end
                end
              end
            end
          end
          
        end

        project.clean do
          rm_rf [cobertura.report_to, cobertura.data_file, cobertura.instrumented_dir], :verbose=>false
        end
        
      end
      
    end

    class Buildr::Project
      include CoberturaExtension
    end

    namespace "cobertura" do

      task "instrument" do
        Buildr.projects.each do |project|
          project.cobertura.data_file = data_file
          project.test.options[:properties]["net.sourceforge.cobertura.datafile"] = data_file
          instrument_task ="#{project.name}:cobertura:instrument"
          task(instrument_task).invoke if Rake::Task.task_defined?(instrument_task)
        end
      end
      
      [:xml, :html].each do |format|
        report_target = report_to(format)
        desc "Run the test cases and produce code coverage reports in #{report_target}"
        task format => ["instrument", "test"] do
          info "Creating test coverage reports in #{report_target}"
          Buildr.ant "cobertura" do |ant|
            ant.taskdef :classpath=>requires.join(File::PATH_SEPARATOR), :resource=>"tasks.properties"
            ant.send "cobertura-report", :destdir=>report_target, :format=>format, :datafile=>data_file do
              Buildr.projects.map(&:cobertura).map(&:sources).flatten.each do |src|
                ant.fileset :dir=>src.to_s if File.exist?(src.to_s)
              end
            end
          end
        end
      end
      
      task "clean" do
        rm_rf [report_to, data_file], :verbose=>false
      end
    end

    task "clean" do
      task("cobertura:clean").invoke if Dir.pwd == Rake.application.original_dir
    end

  end
end
