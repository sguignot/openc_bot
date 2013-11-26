namespace :bot do
  desc "create a skeleton bot that can be used in OpenCorporates"
  task :create do
    working_dir = Dir.pwd
    bot_name = get_bot_name
    new_module_name = bot_name.split('_').collect(&:capitalize).join
    %w(db data lib spec spec/dummy_responses tmp pids).each do |new_dir|
      Dir.mkdir(File.join(working_dir,new_dir)) unless Dir.exist?(File.join(working_dir,new_dir))
    end
    templates = ['spec/spec_helper.rb','spec/bot_spec.rb','lib/bot.rb', 'README.md', 'config.yml']
    templates.each do |template_location|
      template = File.open(File.join(File.dirname(__FILE__), 'templates',template_location)).read
      template.gsub!('MyModule',new_module_name)
      template.gsub!('my_module',bot_name)
      new_file = File.join(working_dir,"#{template_location.sub(/template/,'').sub(/bot/,bot_name)}")
      File.open(new_file, 'w') { |f| f.puts template }
      puts "Created #{new_file}"
    end
    #Add rspec debugger to gemfile
    File.open(File.join(working_dir,'Gemfile'),'a') do |file|
      file.puts "group :test do\n  gem 'rspec'\n  gem 'debugger'\nend"
      puts "Added rspec and debugger to Gemfile at #{file}"
    end
    puts "Please run 'bundle install'"
  end

  desc 'Get data from target'
  task :run do
    only_process_running('run') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      bot_klass = klass_from_file_name(bot_name)
      bot_klass.update_data
    end
  end

  desc 'Export data to stdout'
  task :export do
    only_process_running('export') do
      bot_name = get_bot_name
      require_relative File.join(Dir.pwd,'lib', bot_name)
      bot_klass = klass_from_file_name(bot_name)
      bot_klass.export
    end
  end

  task :test do
    bot_name = get_bot_name
    require_relative File.join(Dir.pwd,'lib', bot_name)
    bot_klass = klass_from_file_name(bot_name)
    results = bot_klass.export_data
    results.each do |datum|
      raise OpencBot::InvalidDataError.new("This datum is invalid: #{datum.inspect}") unless
        OpencBot::BotDataValidator.validate(datum)
    end
    puts "Congratulations! This data appears to be valid"
  end

  def klass_from_file_name(underscore_file_name)
    camelcase_version = underscore_file_name.split('_').map{ |e| e.capitalize }.join
    Object.const_get(camelcase_version)
  end

  def get_bot_name
    #puts "No bot_name given. Using name of current_directory" unless bot_name = ENV['BOT']
    bot_name ||= Dir.pwd.split('/').last
  end

  def only_process_running(task_name)
    pid_path = File.join(Dir.pwd, 'pids', task_name)

    raise_if_already_running(pid_path)
    write_pid_file(pid_path)

    begin
      yield
    ensure
      remove_pid_file(pid_path)
    end
  end

  def raise_if_already_running(pid_path)
    begin
      pid = File.open(pid_path).read.to_i
    rescue Errno::ENOENT
      # PID file doesn't exist
      return
    end

    begin
      Process.getpgid(pid)
    rescue Errno::ESRCH
      # Process with PID doesn't exist
      return
    else
      # Process with PID does exist
      raise 'Already running'
    end
  end

  def write_pid_file(pid_path)
    File.open(pid_path) {|file| file.write(Process.pid)}
  end

  def remove_pid_file(pid_path)
    File.delete(pid_path)
  end
end
