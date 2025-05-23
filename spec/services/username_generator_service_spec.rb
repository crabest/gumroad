# frozen_string_literal: true

require "spec_helper"

describe UsernameGeneratorService do
  describe "#username" do
    let(:user) { build(:user, email: "johnsmith@gmail.com") }
    let(:username_generator) { described_class.new(user) }

    it "returns a username generated by OpenAI", :vcr do
      expect(username_generator.username).to eq "johnsmithy"
    end

    it "adds numbers to the end if the username already exists" do
      existing_username = "johnsmith"
      create(:user, username: existing_username)
      expect(username_generator).to receive(:openai_completion).and_return(existing_username).twice

      generated_username_1 = username_generator.username
      expect(generated_username_1).to match(/\Ajohnsmith\d\z/)
      create(:user, username: generated_username_1)

      generated_username_2 = username_generator.username
      ends_with_different_number = generated_username_1.last != generated_username_2.last
      ends_with_two_numbers = generated_username_2 =~ /\Ajohnsmith\d\d\z/
      expect(ends_with_different_number || ends_with_two_numbers).to be_truthy
    end

    it "uses the user's name when they don't have an email address", :vcr do
      user = build(:user, email: nil, name: "Alexander Nathaniel Harrison")
      expect(described_class.new(user).username).to eq "alxnatharrison"
    end

    it "doesn't try to generate a username if the user doesn't have a name or email" do
      user = build(:user, email: nil, name: nil)
      expect(described_class.new(user).username).to be_nil
    end

    context "email contains a \"tricky\" email with common email domain", :vcr do
      tricky_emails_with_desired_usernames = [
        %w[eduat2@hotmail.com eduquest],
        %w[aholzl@proton.me howlzen],
        %w[barbo816@outlook.com barbossa],
        %w[dtcoats@outlook.com coatsy],
        %w[FuityJuice@mail.com juicyfruit],
        %w[hanglezco@hotmail.com hanglezco],
      ]

      tricky_emails_with_desired_usernames.each do |email, desired_username|
        it "uses the desired username for #{email}" do
          user = build(:user, email:, name: nil)
          expect(described_class.new(user).username).to eq desired_username
        end
      end
    end

    context "OpenAI returns a username that is invalid" do
      it "generates a valid username when given a username with only numbers" do
        expect(username_generator).to receive(:openai_completion).and_return("123")
        user = build(:user, username: username_generator.username)
        expect(user.username).to eq "123a"
        expect(user).to be_valid
      end

      it "generates a valid username when given a blank username" do
        expect(username_generator).to receive(:openai_completion).and_return("")
        user = build(:user, username: username_generator.username)
        expect(user.username).to match(/\Aa\d\d\z/)
        expect(user).to be_valid
      end

      it "generates a valid username when given a username with capital letters and invalid characters" do
        expect(username_generator).to receive(:openai_completion).and_return("John_Smith")
        user = build(:user, username: username_generator.username)
        expect(user.username).to eq "johnsmith"
        expect(user).to be_valid
      end

      it "generates a valid username when given a username that is too short" do
        expect(username_generator).to receive(:openai_completion).and_return("hi")
        user = build(:user, username: username_generator.username)
        expect(user.username).to match(/\Ahi\d\z/)
        expect(user).to be_valid
      end

      it "generates a valid username when given a username that is too long" do
        expect(username_generator).to receive(:openai_completion).and_return("areallyreallylongusername")
        user = build(:user, username: username_generator.username)
        expect(user.username).to eq "areallyreallylonguse"
        expect(user).to be_valid
      end

      it "generates a valid username when given a username that is a word from the DENYLIST" do
        expect(username_generator).to receive(:openai_completion).and_return("about")
        user = build(:user, username: username_generator.username)
        expect(user.username).to match(/\Aabout\d\z/)
        expect(user).to be_valid
      end
    end
  end
end
