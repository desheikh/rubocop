# frozen_string_literal: true

RSpec.describe RuboCop::CLI, :isolated_environment do
  include_context 'cli spec behavior'

  subject(:cli) { described_class.new }

  describe '--disable-uncorrectable' do
    subject(:run_cli) do
      cli.run(%w[--auto-correct --format emacs --disable-uncorrectable])
    end

    it 'does not disable anything for cops that support autocorrect' do
      create_file('.rubocop.yml', <<~YAML)
        Style/FrozenStringLiteralComment:
          Enabled: false
      YAML

      source = <<~RUBY
        puts 1==2
      RUBY
      create_file('example.rb', source)
      expect(run_cli).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(
        "#{abs('example.rb')}:1:7: C: [Corrected] " \
        'Layout/SpaceAroundOperators: ' \
        "Surrounding space missing for operator `==`.\n"
      )

      expected_corrected_source = <<~RUBY
        puts 1 == 2
      RUBY
      expect(IO.read('example.rb')).to eq(expected_corrected_source)
    end

    it 'adds before-and-after disable statement for multiline offenses' do
      create_file('.rubocop.yml', <<~YAML)
        Metrics/MethodLength:
          Max: 1
        Style/FrozenStringLiteralComment:
          Enabled: false
      YAML

      source = <<~RUBY
        def example
          puts 'line 1'
          puts 'line 2'
        end
      RUBY
      create_file('example.rb', source)
      expect(run_cli).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(
        "#{abs('example.rb')}:1:1: C: [Corrected] " \
        'Metrics/MethodLength: ' \
        "Method has too many lines. [2/1]\n"
      )

      expected_corrected_source = <<~RUBY
        # rubocop:disable Metrics/MethodLength
        def example
          puts 'line 1'
          puts 'line 2'
        end
        # rubocop:enable Metrics/MethodLength
      RUBY

      expect(IO.read('example.rb'))
        .to eq(expected_corrected_source)
    end
  end
end
