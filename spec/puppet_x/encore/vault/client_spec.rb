require 'spec_helper'
require 'puppet_x/encore/vault/client'

describe PuppetX::Encore::Vault::Client do
  context 'with default parameters' do
    let(:api_server) { 'vault.domain.tld' }
    let(:api_token) { 'T0ken!' }
    let(:api_port) { 8200 }
    let(:client) { described_class.new(api_server: api_server, api_token: api_token) }

    it 'instantiates' do
      expect(client).to be
      expect(client.instance_variable_get(:@api_port)).to eq(8200)
      expect(client.instance_variable_get(:@api_scheme)).to eq('https')
      expect(client.instance_variable_get(:@api_url)).to eq('https://vault.domain.tld:8200')
      expect(client.instance_variable_get(:@secret_engine)).to eq('/pki')
      expect(client.instance_variable_get(:@ssl_verify)).to eq(OpenSSL::SSL::VERIFY_NONE)
      expect(client.instance_variable_get(:@redirect_limit)).to eq(10)
      expect(client.instance_variable_get(:@headers)).to eq('X-Vault-Token' => 'T0ken!')
    end

    context 'with mock http' do
      let(:mock_http) { instance_double('Net::HTTP') }

      before(:each) do
        allow(mock_http).to receive(:'use_ssl=').with(true)
        allow(mock_http).to receive(:'verify_mode=').with(OpenSSL::SSL::VERIFY_NONE)
        allow(Net::HTTP).to receive(:new).with(api_server, api_port).and_return(mock_http)
      end

      it 'can execute and returns body' do
        mock_response = Net::HTTPSuccess.new(1.0, '200', 'OK')
        expect(mock_response).to receive(:body).and_return('{"test": "value"}')

        expect(mock_http).to receive(:request)
          .with(an_instance_of(Net::HTTP::Get))
          .and_return(mock_response)
        expect(client.execute('get', 'https://vault.domain.tld:8200/test')).to eq('test' => 'value')
      end

      it 'can execute and raises on error response' do
        mock_response = Net::HTTPClientError.new(1.0, '401', 'Unauthorized')
        expect(mock_response).to receive(:body).and_return('Bad request')

        expect(mock_http).to receive(:request)
          .with(an_instance_of(Net::HTTP::Get))
          .and_return(mock_response)
        expect { client.execute('get', 'https://vault.domain.tld:8200/test') }.to raise_error(Net::HTTPServerException)
      end

      it 'can execute and handle redirects' do
        # first response (returns a redirect)
        mock_response1 = Net::HTTPRedirection.new(1.0, '301', 'Moved')
        mock_response1['location'] = 'https://redirectserver:8201/redirected'
        expect(mock_http).to receive(:request)
          .with(an_instance_of(Net::HTTP::Get))
          .and_return(mock_response1)

        # second response (returns a success)
        mock_http2 = instance_double('Net::HTTP')
        allow(mock_http2).to receive(:'use_ssl=').with(true)
        allow(mock_http2).to receive(:'verify_mode=').with(OpenSSL::SSL::VERIFY_NONE)
        allow(Net::HTTP).to receive(:new).with('redirectserver', 8201).and_return(mock_http2)
        mock_response2 = Net::HTTPSuccess.new(1.0, '200', 'OK')
        expect(mock_response2).to receive(:body).and_return('{"test": "value"}')
        expect(mock_http2).to receive(:request)
          .with(an_instance_of(Net::HTTP::Get))
          .and_return(mock_response2)

        expect(client.execute('get', 'https://vault.domain.tld:8200/test')).to eq('test' => 'value')
      end

      it 'can execute and handle redirects to http with correct ssl setting' do
        # first response (returns a redirect)
        mock_response1 = Net::HTTPRedirection.new(1.0, '301', 'Moved')
        mock_response1['location'] = 'http://redirectserver:8201/redirected'
        expect(mock_http).to receive(:request)
          .with(an_instance_of(Net::HTTP::Get))
          .and_return(mock_response1)

        # second response (returns a success)
        mock_http2 = instance_double('Net::HTTP')
        allow(mock_http2).to receive(:'use_ssl=').with(false)
        allow(mock_http2).to receive(:'verify_mode=').with(OpenSSL::SSL::VERIFY_NONE)
        allow(Net::HTTP).to receive(:new).with('redirectserver', 8201).and_return(mock_http2)
        mock_response2 = Net::HTTPSuccess.new(1.0, '200', 'OK')
        expect(mock_response2).to receive(:body).and_return('{"test": "value"}')
        expect(mock_http2).to receive(:request)
          .with(an_instance_of(Net::HTTP::Get))
          .and_return(mock_response2)

        expect(client.execute('get', 'https://vault.domain.tld:8200/test')).to eq('test' => 'value')
      end
    end

    context 'calls get' do
      it 'with default arguments' do
        expect(client).to receive(:execute)
          .with('get', 'https://vault.domain.tld:8200/test',
                body: nil, headers: { 'X-Vault-Token' => 'T0ken!' }, redirect_limit: 10)
          .and_return('test' => 'return')
        expect(client.get('/test')).to eq('test' => 'return')
      end

      it 'with body' do
        expect(client).to receive(:execute)
          .with('get', 'https://vault.domain.tld:8200/test',
                body: 'test body', headers: { 'X-Vault-Token' => 'T0ken!' },
                redirect_limit: 10)
          .and_return('test' => 'return')
        expect(client.get('/test', body: 'test body')).to eq('test' => 'return')
      end

      it 'with body and headers' do
        expect(client).to receive(:execute)
          .with('get', 'https://vault.domain.tld:8200/test',
                body: 'test body', headers: { 'test' => 'header' },
                redirect_limit: 10)
          .and_return('test' => 'return')
        expect(client.get('/test', body: 'test body', headers: { 'test' => 'header' })).to eq('test' => 'return')
      end
    end
  end
end
