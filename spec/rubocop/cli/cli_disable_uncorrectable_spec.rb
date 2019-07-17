# frozen_string_literal: true

RSpec.describe RuboCop::CLI, :isolated_environment do
  include_context 'cli spec behavior'

  subject(:cli) { described_class.new }

  describe '--disable-uncorrectable' do
    let(:exit_code) do
      cli.run(%w[--auto-correct --format simple --disable-uncorrectable])
    end

    it 'does not disable anything for cops that support autocorrect' do
      create_file('example.rb', 'puts 1==2')
      expect(exit_code).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(<<-OUTPUT.strip_indent)
        == example.rb ==
        C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing magic comment # frozen_string_literal: true.
        C:  1:  7: [Corrected] Layout/SpaceAroundOperators: Surrounding space missing for operator ==.

        1 file inspected, 2 offenses detected, 2 offenses corrected
      OUTPUT
      expect(IO.read('example.rb')).to eq(<<-RUBY.strip_indent)
        # frozen_string_literal: true

        puts 1 == 2
      RUBY
    end

    context 'if one one-line disable statement fits' do
      it 'adds it' do
        create_file('example.rb', <<-RUBY.strip_indent)
          def is_example
            true
          end
        RUBY
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<-OUTPUT.strip_indent)
          == example.rb ==
          C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing magic comment # frozen_string_literal: true.
          C:  1:  5: [Todo] Naming/PredicateName: Rename is_example to example?.

          1 file inspected, 2 offenses detected, 2 offenses corrected
        OUTPUT
        expect(IO.read('example.rb')).to eq(<<-RUBY.strip_indent)
          # frozen_string_literal: true

          def is_example # rubocop:disable Naming/PredicateName
            true
          end
        RUBY
      end

      context 'and there are two offenses of the same kind on one line' do
        it 'adds a single one-line disable statement' do
          create_file('.rubocop.yml', <<-YAML.strip_indent)
            Style/IpAddresses:
              Enabled: true
          YAML
          create_file('example.rb', <<-RUBY.strip_indent)
            ip('1.2.3.4', '5.6.7.8')
          RUBY
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<-OUTPUT.strip_indent)
            == example.rb ==
            C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing magic comment # frozen_string_literal: true.
            C:  1:  4: [Todo] Style/IpAddresses: Do not hardcode IP addresses.
            C:  1: 15: [Todo] Style/IpAddresses: Do not hardcode IP addresses.

            1 file inspected, 3 offenses detected, 3 offenses corrected
          OUTPUT
          expect(IO.read('example.rb')).to eq(<<-RUBY.strip_indent)
            # frozen_string_literal: true

            ip('1.2.3.4', '5.6.7.8') # rubocop:disable Style/IpAddresses
          RUBY
        end
      end

      context "but there are more offenses on the line and they don't all " \
              'fit' do
        it 'adds both one-line and before-and-after disable statements' do
          create_file('example.rb', <<-RUBY.strip_indent)
            # Chess engine.
            class Chess
              def choose_move(who_to_move)
                legal_moves = all_legal_moves_that_dont_put_me_in_check(who_to_move)

                return nil if legal_moves.empty?

                mating_move = checkmating_move(legal_moves)
                return mating_move if mating_move

                best_moves = checking_moves(legal_moves)
                best_moves = castling_moves(legal_moves) if best_moves.empty?
                best_moves = taking_moves(legal_moves) if best_moves.empty?
                best_moves = legal_moves if best_moves.empty?
                best_moves = remove_dangerous_moves(best_moves, who_to_move)
                best_moves = legal_moves if best_moves.empty?
                best_moves.sample
              end
            end
          RUBY
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<-OUTPUT.strip_indent)
            == example.rb ==
            C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing magic comment # frozen_string_literal: true.
            C:  3:  3: [Todo] Metrics/AbcSize: Assignment Branch Condition size for choose_move is too high. [15.62/15]
            C:  3:  3: [Todo] Metrics/CyclomaticComplexity: Cyclomatic complexity for choose_move is too high. [7/6]
            C:  3:  3: [Todo] Metrics/MethodLength: Method has too many lines. [11/10]
            C:  5:  3: [Todo] Metrics/AbcSize: Assignment Branch Condition size for choose_move is too high. [15.62/15]
            C:  5:  3: [Todo] Metrics/MethodLength: Method has too many lines. [11/10]
            C:  5: 32: [Corrected] Style/DoubleCopDisableDirective: More than one disable comment on one line.

            1 file inspected, 7 offenses detected, 7 offenses corrected
          OUTPUT
          expect(IO.read('example.rb')).to eq(<<-RUBY.strip_indent)
            # frozen_string_literal: true

            # Chess engine.
            class Chess
              # rubocop:todo Metrics/MethodLength
              # rubocop:todo Metrics/AbcSize
              def choose_move(who_to_move) # rubocop:disable Metrics/CyclomaticComplexity
                legal_moves = all_legal_moves_that_dont_put_me_in_check(who_to_move)

                return nil if legal_moves.empty?

                mating_move = checkmating_move(legal_moves)
                return mating_move if mating_move

                best_moves = checking_moves(legal_moves)
                best_moves = castling_moves(legal_moves) if best_moves.empty?
                best_moves = taking_moves(legal_moves) if best_moves.empty?
                best_moves = legal_moves if best_moves.empty?
                best_moves = remove_dangerous_moves(best_moves, who_to_move)
                best_moves = legal_moves if best_moves.empty?
                best_moves.sample
              end
              # rubocop:enable Metrics/AbcSize
              # rubocop:enable Metrics/MethodLength
            end
          RUBY
        end
      end
    end

    context "if a one-line disable statement doesn't fit" do
      it 'adds before-and-after disable statement' do
        create_file('.rubocop.yml', <<-YAML.strip_indent)
          Metrics/MethodLength:
            Max: 1
        YAML
        create_file('example.rb', <<-RUBY.strip_indent)
          def long_method_name(_taking, _a_few, _parameters, _resulting_in_a_long_line)
            puts 'line 1'
            puts 'line 2'
          end
        RUBY
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<-OUTPUT.strip_indent)
          == example.rb ==
          C:  1:  1: [Todo] Metrics/MethodLength: Method has too many lines. [2/1]
          C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing magic comment # frozen_string_literal: true.

          1 file inspected, 2 offenses detected, 2 offenses corrected
        OUTPUT
        expect(IO.read('example.rb')).to eq(<<-RUBY.strip_indent)
          # rubocop:todo Metrics/MethodLength
          # frozen_string_literal: true

          def long_method_name(_taking, _a_few, _parameters, _resulting_in_a_long_line)
            puts 'line 1'
            puts 'line 2'
          end
          # rubocop:enable Metrics/MethodLength
        RUBY
      end
    end
  end
end
