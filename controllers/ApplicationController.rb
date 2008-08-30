#
#  ApplicationController.rb
#  GitNub
#
#  Created by Justin Palmer on 3/1/08.
#  Copyright (c) 2008 Active Reload, LLC. All rights reserved.
#
require 'boot'
require 'InfoWindowController'

class ApplicationController < OSX::NSObject 
  ib_outlet :commits_table
  ib_outlet :commits_controller 
  ib_outlet :window
  ib_outlet :main_canvas
  ib_outlet :main_view
  ib_outlet :branch_field
  ib_outlet :tab_panel
  ib_outlet :extras_segment
  ib_outlet :local_branches_menu
  ib_outlet :remote_branches_menu
  ib_outlet :tags_menu
  ib_outlet :search_field
  ib_outlet :paging_segment
  ib_outlet :branch_select
  
  def applicationDidFinishLaunching(sender)
    @window.makeKeyAndOrderFront(self)
  end
  
  def applicationShouldTerminateAfterLastWindowClosed(notification)
    return true
  end
  
  def awakeFromNib
    if repo
      @window.delegate = self
      column = @commits_table.tableColumns[0]
      cell = CommitSummaryCell.alloc.init
      column.dataCell = cell
    
      @main_view.setFrameSize(@main_canvas.frame.size)
      @main_canvas.addSubview(@main_view)    
    
      @branch_field.cell.setBackgroundStyle(NSBackgroundStyleRaised)
      @tab_panel.setDelegate(self)
      
      setup_search_field
      setup_refs_view_menu
      load_commands
      
      Notify.on "tab_view_changed" do |opts|
        if(opts[:tab_item] != "commits")
          @paging_segment.setEnabled(false)
          @search_field.setEnabled(false)
        else
          @paging_segment.setEnabled(true)
          @search_field.setEnabled(true)
        end
      end
    end
  end
  
  def repo
    begin
      @repo ||= Grit::Repo.new(REPOSITORY_LOCATION)
    rescue Grit::InvalidGitRepositoryError
      return false
    end
  end
  
  def app_name
    NSFileManager.defaultManager.displayNameAtPath(main_bundle_path)
  end
  
  def main_bundle_path
    NSBundle.mainBundle.bundlePath
  end
  
  def draggingEntered(sender)
    puts sender
  end
  
  ib_action :show_info_panel
  def show_info_panel(sender)
    @info_controller ||= InfoWindowController.alloc.init_with_repository(repo)
    @info_controller.showWindow(self)
  end
  
  ib_action :swap_tab
  def swap_tab(segment)
    tag = %w(commits network)[segment.cell.tagForSegment(segment.selectedSegment)]
    @tab_panel.selectTabViewItemWithIdentifier(tag)
  end
  
  def set_search_category(sender)
    menu = @search_field.cell.searchMenuTemplate
    menu.itemWithTitle(@current_search_item).setState(NSOffState)
    menu.itemWithTitle(sender.title).setState(NSOnState)
    @search_field.cell.setSearchMenuTemplate(menu)
    @current_search_item = sender.title
  end
  
  def search_commits(sender)
    @commits_controller.search_commits(@current_search_item, sender.stringValue)
  end
  
  def tabView_didSelectTabViewItem(tab_view, tab_item)
    Notify.send "tab_view_changed", { :tab_item => tab_item.identifier }
  end
  
  private
    def setup_refs_view_menu
      [@local_branches_menu, @remote_branches_menu, @tags_menu].each { |m| m.submenu.setAutoenablesItems(false) }
      
      heads = repo.heads.reject { |head| head.nil? }
      heads = heads.sort_by do |head|
        name = head.name rescue "temp head"
        name == 'master' ? "***" : name
      end
      
      add_menu_item = lambda do |refs, menu|
        refs.each_with_index do |head, index|
          item = NSMenuItem.alloc.initWithTitle_action_keyEquivalent(head.name, :swap_branch, index.to_s)
          item.setEnabled(true)
          item.setTag(index)
          item.setTarget(@commits_controller)
          menu.submenu.addItem(item)
        end
      end
      
      add_menu_item.call(heads, @local_branches_menu)
      add_menu_item.call(repo.remotes, @remote_branches_menu)
      add_menu_item.call(repo.tags, @tags_menu)
      
      add_menu_item.call(heads, @branch_select.menu.itemAtIndex(0))         #local
      add_menu_item.call(repo.remotes, @branch_select.menu.itemAtIndex(1))  #remote
      add_menu_item.call(repo.tags, @branch_select.menu.itemAtIndex(2))     #tags
      
      current_head = repo.heads.first.name.to_sym rescue nil
      item = @branch_select.itemAtIndex(0).submenu.itemWithTitle(current_head || :master)
      @branch_select.cell.setMenuItem(item)
    end  
    
    def setup_search_field
      @search_menu = NSMenu.alloc.initWithTitle("Search Menu")
      @search_field.cell.setSearchMenuTemplate(@search_menu)
      @search_field.cell.setSendsWholeSearchString(true)
      @search_field.setTarget(self)
      @search_field.setAction(:search_commits)
      @search_menu.setAutoenablesItems(false)
      
      add_menu_item = lambda do |title, tooltip, state|
        item = NSMenuItem.alloc.initWithTitle_action_keyEquivalent(title, :set_search_category, "")
        @search_menu.addItem(item)
        item.setToolTip(tooltip)
        item.setEnabled(true)
        item.setTarget(self)
        if state
          item.setState(NSOnState)
          @current_search_item =  title
        end
      end
      
      add_menu_item.call("Message", "Search commit messages", true)
      add_menu_item.call("SHA1", "Find a commit by its SHA1 hash", false)
      add_menu_item.call("Committer", "Find all all commits by a particular committer", false)
      add_menu_item.call("Author", "Find all all commits by a particular author", false)
      add_menu_item.call("Path", "Find commits based on a path", false)
      @search_field.cell.setPlaceholderString("Search commits...")
    end
    
    def load_commands
      file_manager = NSFileManager.defaultManager 
      search_paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, 
                        NSUserDomainMask, true);

      search_paths.each do |path|
        support_path = File.join(path, app_name)
        unless File.exists?(support_path)
          file_manager.createDirectoryAtPath_attributes(support_path, NSFileTypeDirectory)
        end

        Dir[support_path + "/**/*.gnCommand"].each do |f|
          puts Pathname.new(f).basename
          load f
        end
      end
      
    end
end
