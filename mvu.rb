# Maven Version Updater
#
# parses through all the java projects in your directory, and for any 
# supported pom.xml it updates the version number for all dependencies and 
# plugins if they're out of date
#
# assumes that the user is following the convention.
#
# @author: Jane Jeon

# UPDATE: while I knew there probably was a better way to do this, I was stumped
# at the step where I needed to actually find out the newest version of a
# dependency, which I couldn't do due to inconsistent namings.
# In fact, it turns out there is an established way to update your pom.xml:
# http://www.mojohaus.org/versions-maven-plugin/usage.html
# Still, this was a fun project, and it still manages to find out all the
# dependencies (group, artifact, version) and the corresponding properties
# across *all* pom.xml in all (sub)directories

require 'open-uri'

class Object
  def is_int?
    self.to_i.to_s == self.to_s
  end
end

class Dependency
  def initialize
    @groupId = ''
    @artifactId = ''
    @version = ''
    @alias = false
  end
  
  attr_accessor :groupId, :artifactId, :version, :alias
  
  def specified?
    !groupId.empty? && !artifactId.empty? && !version.empty?
  end
  
  def to_s
    "#{groupId}/#{artifactId} #{version}"
  end
end

def non_negative(input)
  !%w(no n nope false).include? input.downcase
end

def fill(dependency, content, tag_tree)
  # use then dump content
  if tag_tree[-2].eql?('dependency') || tag_tree[-2].eql?('plugin')
    dependency.groupId = content if tag_tree[-1].eql?('groupId')
    dependency.artifactId = content if tag_tree[-1].eql?('artifactId')
    if tag_tree[-1].eql?('version')
      if content[0].is_int?
        dependency.version = content
      else
        dependency.version = content[2...-1]
        dependency.alias = true
      end
    end
  end
end

def url(dependency)
  'https://mvnrepository.com/artifact/' +
  "#{dependency.groupId}/#{dependency.artifactId}"
end

# finds out what is the latest version of dependency from maven repository
# TODO
def update(source)
  # m = source.scan(/artifact(.*?)central/)
  # puts m[0]
end

# default directory is the directory of this file
path = Dir.pwd

puts "Current path: #{path}. Change path?"
ans = gets.chomp

if !ans.empty? && non_negative(ans)
  loop do
    if Dir.exist?ans
      path = ans
      break
    end
    puts 'Not a valid path. Enter a new path:'
    ans = gets.chomp
  end
end

# if path ends with '/', delete it
path = path[0...-1] if path[-1].eql?('/')

log = {}

# finding all pom in all subdirectories of the specified path
Dir.glob(path + '/**/pom.xml') do |doc|
  # <tag>content</tag>
  tag = ''
  prev = ''
  content = ''
  tag_tree = []
  tag_mode = false
  content_mode = false
  properties = {}
  dependency = Dependency.new
  # my own XML parser rather than nekogiri because I don't want gem dependency.
  # also, I can't really use regex for this, since I need to verify both
  # the tags of the dependency and its parent tag
  File.readlines(doc).each do |line|
    line.split('').each do |c|
      # closing tag -- assumes that no tag is empty <>
      if c.eql?('>') && tag_mode
        tag_mode = false
        tag_tree << tag
        tag = ''
      end
      # matching tag
      if c.eql?('/') && prev.eql?('<')
        tag_mode = false
        tag_tree = tag_tree[0...-1]
      end
      tag << c if tag_mode
      # opening tag
      if c.eql?('<')
        tag_mode = true
        content_mode = false
        unless content.empty?
          # check properties
          properties[tag_tree[-1]] = content if tag_tree[-2].eql?('properties')
          # use then dump content
          fill(dependency, content, tag_tree)
          content = ''
        end
      end
      content << c if content_mode
      content_mode = true if c.eql?('>')
      prev = c
      # dependency management
      if dependency.specified?
        updated = false
        to_check = ''
        # check version
        if !dependency.alias
          to_check = dependency.version
        elsif properties.has_key?(dependency.version)
          to_check = properties[dependency.version]
        end
        # look up the latest maven repository
        unless to_check.empty?
          updated = true
          puts doc.to_s
          puts url(dependency)
          update(open(url(dependency)).read)
        end
        if updated
          log.has_key?(doc.to_s) ?
              log[doc.to_s] << dependency :
              log[doc.to_s] = [dependency]
        end
        dependency = Dependency.new
      end
    end
  end
end

puts 'report:'
log.each_key do |key|
  puts key
  log[key].each do |value|
    puts "\t#{value}"
  end
end