# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
RSpec.describe MicrosoftKiotaAbstractions do
  it 'adds a request header to the request information' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.headers.add('key', 'value')
    expect(request_info.headers.get_all.length).to eq(1)
    expect(request_info.headers.get('key').length).to eq(1)
    expect(request_info.headers.get('key').first).to eq('value')
  end

  it 'adds a request header to the request information when one value is already present' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.headers.add('key', 'value')
    request_info.headers.add('key', 'value2')
    expect(request_info.headers.get_all.length).to eq(1)
    expect(request_info.headers.get('key').length).to eq(2)
    expect(request_info.headers.get('key').first).to eq('value')
    expect(request_info.headers.get('key').last).to eq('value2')
  end

  it 'try to add a request header to the request information' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    result1 = request_info.headers.try_add('key', 'value')
    result2 = request_info.headers.try_add('key', 'value2')
    expect(result1).to eq(true)
    expect(result2).to eq(false)
    expect(request_info.headers.get_all.length).to eq(1)
    expect(request_info.headers.get('key').length).to eq(1)
    expect(request_info.headers.get('key').first).to eq('value')
  end

  it 'removes a request header from the request information' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.headers.add('key', 'value')
    expect(request_info.headers.get_all.length).to eq(1)
    request_info.headers.remove('key')
    expect(request_info.headers.get_all.length).to eq(0)
  end

  it 'doesnt fail when removing a value if none are present' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.headers.remove('key')
    expect(request_info.headers.get_all.length).to eq(0)
  end

  it 'clears the request headers from the request information' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.headers.add('key', 'value')
    expect(request_info.headers.get_all.length).to eq(1)
    request_info.headers.clear
    expect(request_info.headers.get_all.length).to eq(0)
  end

  it 'handles header operations case-insensitively' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    headers.add('Content-Type', 'application/json')

    expect(headers.key?('content-type')).to be(true)
    expect(headers.key?('CONTENT-TYPE')).to be(true)
    expect(headers.get('content-type')).to eq(['application/json'])
    expect(headers.get('CONTENT-TYPE')).to eq(['application/json'])

    expect(headers.try_add('content-type', 'application/xml')).to be(false)
    expect(headers.get('Content-Type')).to eq(['application/json'])

    headers.add('content-type', 'charset=utf-8')
    expect(headers.get('CONTENT-TYPE')).to eq(['application/json', 'charset=utf-8'])

    headers.remove('content-type')
    expect(headers.key?('Content-Type')).to be(false)
    expect(headers.get('Content-Type')).to be_nil
  end

  it 'supports non-string scalar values without raising' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    expect { headers.add('Content-Length', 1024) }.not_to raise_error
    expect(headers.get('Content-Length')).to eq(['1024'])

    expect { headers.try_add('Max-Forwards', 10) }.not_to raise_error
    expect(headers.get('Max-Forwards')).to eq(['10'])

    headers.add('X-Flag', true)
    expect(headers.get('X-Flag')).to eq(['true'])
  end

  it 'deduplicates identical header values' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    headers.add('Accept', 'application/json')
    headers.add('Accept', 'application/json')
    expect(headers.get('Accept')).to eq(['application/json'])
  end

  it 'handles Symbol header keys interoperably with String keys' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    headers.add(:'Content-Type', 'application/json')

    expect(headers.key?('content-type')).to be(true)
    expect(headers.key?(:'content-type')).to be(true)
    expect(headers.get('content-type')).to eq(['application/json'])
    expect(headers.get(:'CONTENT-TYPE')).to eq(['application/json'])

    expect(headers.try_add('Content-Type', 'application/xml')).to be(false)
    expect(headers.get(:'Content-Type')).to eq(['application/json'])

    headers.add('content-type', 'charset=utf-8')
    expect(headers.get('content-type')).to eq(['application/json', 'charset=utf-8'])

    headers.remove('content-type')
    expect(headers.key?(:'Content-Type')).to be(false)
    expect(headers.get(:'Content-Type')).to be_nil

    headers.add('Authorization', 'Bearer token')
    expect(headers.key?(:authorization)).to be(true)
    expect(headers.get(:AUTHORIZATION)).to eq(['Bearer token'])
    headers.remove(:authorization)
    expect(headers.key?('Authorization')).to be(false)
  end
end
