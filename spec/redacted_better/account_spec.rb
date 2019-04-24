require "spec_helper"

describe Account do
  subject(:account) { described_class.new }

  describe "#login" do
    context "when login info is correct" do
      it "logs in" do
        account.instance_variable_set(:@username, "user")
        account.instance_variable_set(:@password, "pass")

        expect(account.login).to be true
        expect(account.cookie).to eq "session=asdf1234"
        expect(account.user_id).to eq 4517
      end
    end

    context "when login info is incorrect" do
      it "prints the error and returns false" do
        conn = instance_double("Faraday::Connection")
        response = instance_double("Faraday::Response")
        allow(conn).to receive(:post).and_return(response)
        allow(Faraday).to receive(:new).and_return(conn)
        allow(response).to receive(:status).and_return(200)

        expect(account.login).to be false
      end
    end

    context "when there is an unexpected return code" do
      it "prints the error and returns false" do
        conn = instance_double("Faraday::Connection")
        response = instance_double("Faraday::Response")
        allow(conn).to receive(:post).and_return(response)
        allow(Faraday).to receive(:new).and_return(conn)
        allow(response).to receive(:status).and_return(500)

        expect(account.login).to be false
      end
    end

    context "when the login request times out" do
      it "prints the error and returns false" do
        conn = instance_double("Faraday::Connection")
        allow(conn).to receive(:post) { raise Faraday::TimeoutError }
        allow(Faraday).to receive(:new).and_return(conn)

        expect(account.login).to be false
      end
    end
  end
end
