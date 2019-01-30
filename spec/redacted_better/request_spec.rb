require 'spec_helper'

describe Request do
  describe '.send_request' do
    it 'sends a request' do
      allow(described_class).to receive(:wait_for_request)
      query = { 'action' => 'the_action', 'extra_param' => 'value' }
      headers = { 'Cookie' => 'the_cookie' }
      body = { status: 'success', response: '{}' }.to_json

      stub = stub_request(:get, 'https://redacted.ch/ajax.php')
             .with(query: query, headers: headers)
             .to_return(body: body, status: 200)

      result = described_class.send_request(action: 'the_action', cookie: 'the_cookie', params: { 'extra_param' => 'value' })

      expect(result[:code]).to eq 200
      expect(result[:status]).to eq 'success'
      expect(result[:response]).to eq('{}')
      expect(stub).to have_been_requested.once
    end
  end
end
