# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  class TypeInferrerTest < Minitest::Test
    def setup
      @index = RubyIndexer::Index.new
      @type_inferrer = TypeInferrer.new(@index)
    end

    def test_infer_receiver_type_self_inside_method
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo
          def bar
            baz
          end
        end
      RUBY

      assert_equal("Foo", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_self_inside_class_body
      node_context = index_and_locate(<<~RUBY, { line: 1, character: 2 })
        class Foo
          baz
        end
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_self_inside_singleton_method
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo
          def self.bar
            baz
          end
        end
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_self_inside_singleton_block_body
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo
          class << self
            baz
          end
        end
      RUBY

      assert_equal("Foo::<Class:Foo>::<Class:<Class:Foo>>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_self_inside_singleton_block_method
      node_context = index_and_locate(<<~RUBY, { line: 3, character: 6 })
        class Foo
          class << self
            def bar
              baz
            end
          end
        end
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_constant
      node_context = index_and_locate(<<~RUBY, { line: 4, character: 4 })
        class Foo
          def bar; end
        end

        Foo.bar
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_constant_path
      node_context = index_and_locate(<<~RUBY, { line: 6, character: 9 })
        module Foo
          class Bar
            def baz; end
          end
        end

        Foo::Bar.baz
      RUBY

      assert_equal("Foo::Bar::<Class:Bar>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_top_level_receiver
      node_context = index_and_locate(<<~RUBY, { line: 0, character: 0 })
        foo
      RUBY

      assert_equal("Object", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_instance_variables_in_class_body
      node_context = index_and_locate(<<~RUBY, { line: 1, character: 2 })
        class Foo
          @hello1
        end
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_instance_variables_in_singleton_method
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo
          def self.bar
            @hello1
          end
        end
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_instance_variables_in_singleton_block_body
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo
          class << self
            @hello1
          end
        end
      RUBY

      assert_equal("Foo::<Class:Foo>::<Class:<Class:Foo>>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_instance_variables_in_singleton_block_method
      node_context = index_and_locate(<<~RUBY, { line: 3, character: 6 })
        class Foo
          class << self
            def bar
              @hello1
            end
          end
        end
      RUBY

      assert_equal("Foo::<Class:Foo>", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_receiver_type_instance_variables_in_instance_method
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo
          def bar
            @hello1
          end
        end
      RUBY

      assert_equal("Foo", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_top_level_instance_variables
      node_context = index_and_locate(<<~RUBY, { line: 0, character: 0 })
        @foo
      RUBY

      assert_equal("Object", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_guessed_types_for_local_variable_receiver
      node_context = index_and_locate(<<~RUBY, { line: 4, character: 5 })
        class User
        end

        user = something
        user.name
      RUBY

      assert_equal("User", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_guessed_types_for_instance_variable_receiver
      node_context = index_and_locate(<<~RUBY, { line: 4, character: 6 })
        class User
        end

        @user = something
        @user.name
      RUBY

      assert_equal("User", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_guessed_types_for_method_call_receiver
      node_context = index_and_locate(<<~RUBY, { line: 3, character: 5 })
        class User
        end

        user.name
      RUBY

      assert_equal("User", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_guessed_types_inside_nesting
      node_context = index_and_locate(<<~RUBY, { line: 9, character: 9 })
        module Blog
          class User
          end
        end

        module Admin
          class User
          end

          user.name
        end
      RUBY

      assert_equal("Admin::User", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_forwading_super_receiver
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo < Bar
          def initialize
            super
          end
        end
      RUBY

      assert_equal("Foo", @type_inferrer.infer_receiver_type(node_context).name)
    end

    def test_infer_super_receiver
      node_context = index_and_locate(<<~RUBY, { line: 2, character: 4 })
        class Foo < Bar
          def initialize(a, b, c)
            super()
          end
        end
      RUBY

      assert_equal("Foo", @type_inferrer.infer_receiver_type(node_context).name)
    end

    private

    def index_and_locate(source, position)
      @index.index_single(RubyIndexer::IndexablePath.new(nil, "/fake/path/foo.rb"), source)
      document = RubyLsp::RubyDocument.new(
        source: source,
        version: 1,
        uri: URI::Generic.build(scheme: "file", path: "/fake/path/foo.rb"),
      )
      document.locate_node(position)
    end
  end
end
