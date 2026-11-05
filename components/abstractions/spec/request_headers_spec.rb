# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

RSpec.describe 'RequestHeaders through RequestInformation' do
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
end

RSpec.describe MicrosoftKiotaAbstractions::RequestHeaders do
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

  it 'handles non-string keys in direct header operations' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    headers.add(123, 'num-header')
    expect(headers.key?(123)).to be(true)
    expect(headers.key?('123')).to be(true)
    expect(headers.get(123)).to eq(['num-header'])
    expect(headers.get('123')).to eq(['num-header'])
    expect(headers.get_all.keys).to contain_exactly('123')
    expect(headers.get_all.keys.first).to be_a(String)

    expect(headers.try_add(123, 'num-header-2')).to be(false)
    headers.remove(123)
    expect(headers.key?(123)).to be(false)
  end

  it 'stores non-string keys as strings in get_all' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    headers.add(123, 'num-header')
    headers.try_add(456, 'num-header-2')
    expect(headers.get_all.keys).to contain_exactly('123', '456')
    expect(headers.get_all.keys).to all(be_a(String))
  end

  it 'handles symbol keys and case-insensitive matching across types' do
    headers = MicrosoftKiotaAbstractions::RequestHeaders.new
    headers.add(:authorization, 'Bearer 1')
    expect(headers.get_all.keys).to contain_exactly('authorization')
    expect(headers.key?('AUTHORIZATION')).to be(true)
    expect(headers.key?(:authorization)).to be(true)

    headers.add('AUTHORIZATION', 'Bearer 2')
    expect(headers.get('authorization')).to eq(['Bearer 1', 'Bearer 2'])
    expect(headers.get(:authorization)).to eq(['Bearer 1', 'Bearer 2'])
    expect(headers.get_all.keys.size).to eq(1)

    headers.remove(:authorization)
    expect(headers.key?('authorization')).to be(false)
  end
end

RSpec.describe 'MicrosoftKiotaAbstractions::RequestHeaders#add_all' do
  it 'adds all headers from another RequestHeaders instance' do
    source = MicrosoftKiotaAbstractions::RequestHeaders.new
    source.add('Accept', 'application/json')
    source.add('User-Agent', 'test-client')

    target = MicrosoftKiotaAbstractions::RequestHeaders.new
    target.add('Authorization', 'Bearer token')
    target.add_all(source)

    expect(target.get('Accept')).to eq(['application/json'])
    expect(target.get('User-Agent')).to eq(['test-client'])
    expect(target.get('Authorization')).to eq(['Bearer token'])
  end

  it 'adds all headers from a Hash' do
    target = MicrosoftKiotaAbstractions::RequestHeaders.new
    target.add_all({ 'Accept' => 'application/json', 'X-Custom' => 'value' })

    expect(target.get('Accept')).to eq(['application/json'])
    expect(target.get('X-Custom')).to eq(['value'])
  end

  it 'adds all headers from a Hash with non-string keys' do
    target = MicrosoftKiotaAbstractions::RequestHeaders.new
    target.add_all({ 123 => 'numeric-header', :symbol_header => 'sym-val' })

    expect(target.get('123')).to eq(['numeric-header'])
    expect(target.get('symbol_header')).to eq(['sym-val'])
  end

  it 'ignores nil in add_all' do
    target = MicrosoftKiotaAbstractions::RequestHeaders.new
    expect { target.add_all(nil) }.not_to raise_error
    expect(target.get_all).to be_empty
  end
end
