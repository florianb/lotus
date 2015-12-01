require 'test_helper'
require 'lotus/commands/generate/action'
require 'fileutils'

describe Lotus::Commands::Generate::Action do
  describe 'with invalid arguments' do
    it 'requires application name' do
      with_temp_dir do |original_wd|
        setup_container_app
        -> { Lotus::Commands::Generate::Action.new({}, nil, 'books#index') }.must_raise ArgumentError
        -> { Lotus::Commands::Generate::Action.new({}, '', 'books#index') }.must_raise ArgumentError
        -> { Lotus::Commands::Generate::Action.new({}, '  ', 'books#index') }.must_raise ArgumentError
      end
    end

    it 'requires controller and action name' do
      with_temp_dir do |previus_wd|
        setup_container_app
        -> { Lotus::Commands::Generate::Action.new({}, 'web', 'books') }.must_raise ArgumentError
        -> { Lotus::Commands::Generate::Action.new({}, 'web', '') }.must_raise ArgumentError
        -> { Lotus::Commands::Generate::Action.new({}, 'web', ' ') }.must_raise ArgumentError
      end
    end

    it 'verifies the method option' do
      with_temp_dir do |previus_wd|
        setup_container_app
        -> { Lotus::Commands::Generate::Action.new({method: 'UnKnOwN'}, 'web', 'books#action') }.must_raise ArgumentError
      end
    end
  end

  describe 'with valid arguments' do
    it 'allows user to pass / instead of # between controller and action' do
      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({}, 'web', 'books/index')
        capture_io { command.start }

        assert_file_exists 'apps/web/templates/books/index.html.erb'
        assert_file_includes('apps/web/config/routes.rb', "get '/books', to: 'books#index'")
      end
    end

    it 'uses --template option as extension for the template' do
      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({template: 'haml'}, 'web', 'books#index')

        capture_io { command.start }

        assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/template.html.haml'), 'apps/web/templates/books/index.html.haml')
      end
    end

    it "handles nested routes correctly" do
      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({}, 'web', 'admin/books#index')
        capture_io { command.start }

        assert_file_exists 'apps/web/templates/admin/books/index.html.erb'
        assert_file_includes('apps/web/config/routes.rb', "get '/admin/books', to: 'admin/books#index'")
      end

      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({}, 'web', 'admin/books/index')
        capture_io { command.start }

        assert_file_exists 'apps/web/templates/admin/books/index.html.erb'
        assert_file_includes('apps/web/config/routes.rb', "get '/admin/books', to: 'admin/books#index'")
      end
    end

    describe 'route options' do
      it 'uses the --method option to specify HTTP method in the route' do
        with_temp_dir do |original_wd|
          setup_container_app
          Lotus::Routing::Route::VALID_HTTP_VERBS.each do |m|
            command = Lotus::Commands::Generate::Action.new({method: m}, 'web', 'books#index')
            capture_io { command.start }

            assert_file_includes('apps/web/config/routes.rb', "#{m.downcase} '/books', to: 'books#index'")
          end
        end
      end

      it 'uses the --url option to specify the route url' do
        with_temp_dir do |original_wd|
          setup_container_app

          command = Lotus::Commands::Generate::Action.new({url: '/mybooks'}, 'web', 'books#index')
          capture_io { command.start }

          assert_file_includes('apps/web/config/routes.rb', "get '/mybooks', to: 'books#index'")
        end
      end
    end

    describe 'resourceful HTTP default methods' do
      it 'uses POST for "create" action' do
        with_temp_dir do |original_wd|
          setup_container_app
          command = Lotus::Commands::Generate::Action.new({}, 'web', 'books/create')
          capture_io { command.start }

          assert_file_includes('apps/web/config/routes.rb', "post '/books', to: 'books#create'")
        end
      end

      it 'uses PATCH for "update" action' do
        with_temp_dir do |original_wd|
          setup_container_app
          command = Lotus::Commands::Generate::Action.new({}, 'web', 'books/update')
          capture_io { command.start }

          assert_file_includes('apps/web/config/routes.rb', "patch '/books', to: 'books#update'")
        end
      end

      it 'uses DELETE for "destroy" action' do
        with_temp_dir do |original_wd|
          setup_container_app
          command = Lotus::Commands::Generate::Action.new({}, 'web', 'books/destroy')
          capture_io { command.start }

          assert_file_includes('apps/web/config/routes.rb', "delete '/books', to: 'books#destroy'")
        end
      end

      it 'does not override user specified http method' do
        with_temp_dir do |original_wd|
          setup_container_app
          command = Lotus::Commands::Generate::Action.new({method: 'get'}, 'web', 'books/create')
          capture_io { command.start }

          assert_file_includes('apps/web/config/routes.rb', "get '/books', to: 'books#create'")
        end
      end
    end

    describe 'container architecture' do
      describe 'with minitest' do
        it 'generates the files' do
          with_temp_dir do |original_wd|
            setup_container_app

            command = Lotus::Commands::Generate::Action.new({}, 'web', 'books#index')
            capture_io { command.start }

            assert_generated_container_action('minitest', original_wd)
          end
        end

        it 'functions normally when app name has underscore' do
          with_temp_dir do |original_wd|
            setup_underscored_container_app

            command = Lotus::Commands::Generate::Action.new({}, 'app_v1', 'books#index')
            capture_io { command.start }

            assert_file_exists('spec/app_v1/controllers/books/index_spec.rb')
            assert_file_exists('apps/app_v1/controllers/books/index.rb')
            assert_file_exists('apps/app_v1/views/books/index.rb')
            assert_file_exists('apps/app_v1/templates/books/index.html.erb')
            assert_file_exists('spec/app_v1/views/books/index_spec.rb')
            assert_file_exists('apps/app_v1/config/routes.rb')
          end
        end

        it 'skips the view' do
          with_temp_dir do |original_wd|
            setup_container_app

            command = Lotus::Commands::Generate::Action.new({skip_view: true}, 'web', 'books#index')
            capture_io { command.start }

            assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/routes.get.rb'), 'apps/web/config/routes.rb')
            assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/action_spec.container.minitest.rb'), 'spec/web/controllers/books/index_spec.rb')
            assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/action_without_view.container.rb'), 'apps/web/controllers/books/index.rb')

            refute_file_exists('apps/web/views/books/index.rb')
            refute_file_exists('apps/web/templates/books/index.html.erb')
            refute_file_exists('spec/web/views/books/index_spec.rb')
          end
        end
      end

      describe 'with rspec' do
        it 'generates the files' do
          with_temp_dir do |original_wd|
            setup_container_app

            command = Lotus::Commands::Generate::Action.new({test: 'rspec'}, 'web', 'books#index')
            capture_io { command.start }

            assert_generated_container_action('rspec', original_wd)
          end
        end
      end
    end

    describe 'app architecture' do
      describe 'with minitest' do
        it 'generates the files' do
          with_temp_dir do |original_wd|
            setup_app_app

            command = Lotus::Commands::Generate::Action.new({}, 'testapp', 'books#index')
            capture_io { command.start }

            assert_generated_app_action('minitest', original_wd)
          end
        end

        it 'skips the view' do
          with_temp_dir do |original_wd|
            setup_app_app

            command = Lotus::Commands::Generate::Action.new({skip_view: true}, 'testapp', 'books#index')
            capture_io { command.start }

            assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/routes.get.rb'), 'config/routes.rb')
            assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/action_spec.app.minitest.rb'), 'spec/controllers/books/index_spec.rb')
            assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/action_without_view.app.rb'), 'app/controllers/books/index.rb')

            refute_file_exists('apps/web/views/books/index.rb')
            refute_file_exists('apps/web/templates/books/index.html.erb')
            refute_file_exists('spec/web/views/books/index_spec.rb')
          end
        end
      end

      describe 'with rspec' do
        it 'generates the files' do
          with_temp_dir do |original_wd|
            setup_app_app

            command = Lotus::Commands::Generate::Action.new({test: 'rspec'}, 'testapp', 'books#index')
            capture_io { command.start }

            assert_generated_app_action('rspec', original_wd)
          end
        end
      end
    end
  end

  describe 'with quoted arguments' do
    # See https://github.com/lotus/lotus/issues/282
    it 'accepts single quoted arguments' do
      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({}, 'web', "'books#index'")
        capture_io { command.start }

        assert_generated_container_action('minitest', original_wd)
      end
    end

    it 'accepts double quoted arguments' do
      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({}, 'web', '"books#index"')
        capture_io { command.start }

        assert_generated_container_action('minitest', original_wd)
      end
    end

    it 'accepts escaped arguments' do
      with_temp_dir do |original_wd|
        setup_container_app
        command = Lotus::Commands::Generate::Action.new({}, 'web', 'books\#index')
        capture_io { command.start }

        assert_generated_container_action('minitest', original_wd)
      end
    end
  end

  describe '#destroy' do
    describe 'with container architecture' do
      it 'destroys action, specs and templates' do
        with_temp_dir do |original_wd|
          setup_container_app

          capture_io {
            Lotus::Commands::Generate::Action.new({}, 'web', 'books#index').start

            Lotus::Commands::Generate::Action.new({}, 'web', 'books#index').destroy.start
          }

          refute_file_exists('spec/web/controllers/books/index_spec.rb')
          refute_file_exists('apps/web/controllers/books/index.rb')
          refute_file_exists('apps/web/views/books/index.rb')
          refute_file_exists('apps/web/templates/books/index.html.erb')
          refute_file_exists('spec/web/views/books/index_spec.rb')
        end
      end
    end

    describe 'with app architecture' do
      it 'destroys action, specs and templates' do
        with_temp_dir do |original_wd|
          setup_app_app

          capture_io {
            Lotus::Commands::Generate::Action.new({}, 'testapp', 'books#index').start

            Lotus::Commands::Generate::Action.new({}, 'testapp', 'books#index').destroy.start
          }

          refute_file_exists('spec/controllers/books/index_spec.rb')
          refute_file_exists('app/controllers/books/index.rb')
          refute_file_exists('app/views/books/index.rb')
          refute_file_exists('app/templates/books/index.html.erb')
          refute_file_exists('spec/views/books/index_spec.rb')
        end
      end
    end

    it 'erases route configuration' do
      with_temp_dir do |original_wd|
        setup_container_app

        capture_io {
          Lotus::Commands::Generate::Action.new({}, 'web', 'books#index').start

          Lotus::Commands::Generate::Action.new({}, 'web', 'books#index').destroy.start
        }

        refute_file_includes('apps/web/config/routes.rb', "get '/books', to: 'books#index'")
      end
    end

    describe 'with --url' do
      it 'erases route configuration' do
        with_temp_dir do |original_wd|
          setup_container_app

          capture_io {
            Lotus::Commands::Generate::Action.new({url: '/mybooks'}, 'web', 'books#index').start

            Lotus::Commands::Generate::Action.new({url: '/mybooks'}, 'web', 'books#index').destroy.start
          }

          refute_file_includes('apps/web/config/routes.rb', "get '/mybooks', to: 'books#index'")
        end
      end
    end

    describe 'with --method' do
      it 'erases route configuration' do
        with_temp_dir do |original_wd|
          setup_container_app

          capture_io {
            Lotus::Commands::Generate::Action.new({method: 'post'}, 'web', 'books#index').start

            Lotus::Commands::Generate::Action.new({method: 'post'}, 'web', 'books#index').destroy.start
          }

          refute_file_includes('apps/web/config/routes.rb', "post '/books', to: 'books#index'")
        end
      end
    end

    describe 'with --template' do
      it 'destroys template' do
        with_temp_dir do |original_wd|
          setup_container_app

          capture_io {
            Lotus::Commands::Generate::Action.new({template: 'haml'}, 'web', 'books#index').start

            Lotus::Commands::Generate::Action.new({template: 'haml'}, 'web', 'books#index').destroy.start
          }

          refute_file_exists('apps/web/templates/books/index.html.haml')
        end
      end
    end
  end

  describe 'respect lotusrc' do
    it 'creates rspec templates' do
      with_temp_dir do |original_wd|
        setup_container_app
        FileUtils.cp original_wd.join('test', 'fixtures', 'lotusrc', 'with_rspec'), '.lotusrc'

        capture_io {
          Lotus::Commands::Generate::Action.new({}, 'web', 'books#index').start
        }
        assert_generated_container_action('rspec', original_wd)
      end
    end

    it 'accepts command arguments to override lotusrc' do
      with_temp_dir do |original_wd|
        setup_container_app
        FileUtils.cp original_wd.join('test', 'fixtures', 'lotusrc', 'with_rspec'), '.lotusrc'

        capture_io {
          Lotus::Commands::Generate::Action.new({test: 'minitest'}, 'web', 'books#index').start
        }
        assert_generated_container_action('minitest', original_wd)
      end
    end

  end

  def assert_generated_app_action(test_framework, original_wd)
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/routes.get.rb'), 'config/routes.rb')
    assert_generated_file(original_wd.join("test/fixtures/commands/generate/action/action_spec.app.#{test_framework}.rb"), 'spec/controllers/books/index_spec.rb')
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/action.app.rb'), 'app/controllers/books/index.rb')
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/view.app.rb'), 'app/views/books/index.rb')
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/template.html.erb'), 'app/templates/books/index.html.erb')
    assert_generated_file(original_wd.join("test/fixtures/commands/generate/action/view_spec.app.#{test_framework}.rb"), 'spec/views/books/index_spec.rb')
  end

  def assert_generated_container_action(test_framework, original_wd)
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/routes.get.rb'), 'apps/web/config/routes.rb')
    assert_generated_file(original_wd.join("test/fixtures/commands/generate/action/action_spec.container.#{test_framework}.rb"), 'spec/web/controllers/books/index_spec.rb')
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/action.container.rb'), 'apps/web/controllers/books/index.rb')
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/view.container.rb'), 'apps/web/views/books/index.rb')
    assert_generated_file(original_wd.join('test/fixtures/commands/generate/action/template.html.erb'), 'apps/web/templates/books/index.html.erb')
    assert_generated_file(original_wd.join("test/fixtures/commands/generate/action/view_spec.container.#{test_framework}.rb"), 'spec/web/views/books/index_spec.rb')
  end

  def setup_container_app
    File.open('.lotusrc', 'w') { |file| file << "architecture=container"}
    FileUtils.mkdir_p('apps/web') # simulate existing app
    FileUtils.mkdir_p('apps/web/config') # simulate existing routes file to see if route is prepended
    File.open('apps/web/config/routes.rb', 'w') { |file| file << "get '/cars', to: 'cars#index'"}
  end

  def setup_underscored_container_app
    File.open('.lotusrc', 'w') { |file| file << "architecture=container"}
    FileUtils.mkdir_p('apps/app_v1') # simulate existing app
    FileUtils.mkdir_p('apps/app_v1/config') # simulate existing routes file to see if route is prepended
    File.open('apps/app_v1/config/routes.rb', 'w') { |file| file << "get '/cars', to: 'cars#index'"}
  end

  def setup_app_app
    File.open('.lotusrc', 'w') { |file| file << "architecture=app"}
    FileUtils.mkdir_p('app') # simulate existing app
    FileUtils.mkdir_p('config') # simulate existing routes file to see if route is prepended
    File.open('config/routes.rb', 'w') { |file| file << "get '/cars', to: 'cars#index'"}
  end
end
