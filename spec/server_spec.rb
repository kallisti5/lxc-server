require 'spec_helper'

describe LXC::Server do
  it 'GET /version returns server version' do
    get '/version'
    last_response.should be_ok
    parse_json(last_response.body)['version'].should eq(LXC::SERVER_VERSION)
  end

  it 'GET /lxc_version returns installed LXC version' do
    stub_lxc('version') { fixture('lxc-version.txt') }

    get '/lxc_version'
    last_response.should be_ok
    parse_json(last_response.body)['version'].should eq('0.7.5')
  end

  it 'GET /containers returns a list of containers' do
    stub_lxc('ls') { "app" }
    stub_lxc('info', '-n', 'app') { fixture('lxc-info-running.txt') }

    get '/containers'
    last_response.should be_ok
    
    data = parse_json(last_response.body)
    data.should be_an Array
    data.should_not be_empty
    keys = data.first.keys
    keys.include?('name').should be_true
    keys.include?('state').should be_true
    keys.include?('pid').should be_true
  end

  it 'GET /container/:name returns a single container' do
    stub_lxc('ls') { "app" }
    stub_lxc('info', '-n', 'app') { fixture('lxc-info-running.txt') }

    get '/containers/app'
    last_response.should be_ok

    data = parse_json(last_response.body)
    data.should be_a Hash
    data.should_not be_empty
    data['name'].should eq('app')
    data['state'].should eq('RUNNING')
    data['pid'].should eq('2125')
  end

  it 'GET /container/:name/memory return current memory usage' do
    stub_lxc('ls') { "app" }
    stub_lxc('cgroup', '-n', 'app', 'memory.usage_in_bytes') { "123456\n" }

    get '/containers/app/memory'
    last_response.should be_ok

    data = parse_json(last_response.body)
    data.should be_a Hash
    data['memory'].should eq(123456)
  end

  it 'GET /container/:name/processes returns current running processes' do
    stub_lxc('ls') { "app" }
    stub_lxc('info', '-n', 'app') { fixture('lxc-info-running.txt') }
    stub_lxc('ps', '-n', 'app', '--', '-eo pid,user,%cpu,%mem,args') { fixture('lxc-ps-aux.txt') }

    get '/containers/app/processes'
    last_response.should be_ok

    data = parse_json(last_response.body)
    data.should be_an Array
    data.first.should be_a Hash
  end

  context 'Errors' do
    class LXC::Server
      get '/exception' do
        raise RuntimeError, "Something went wrong"
      end
    end

    it 'renders error message on non-existent route' do
      get '/foo-bar'
      last_response.should_not be_ok
      last_response.status.should eq(404)
      parse_json(last_response.body)['error'].should eq('Invalid request path')
    end

    it 'renders exception message on internal server error' do
      get '/exception'
      last_response.should_not be_ok
      last_response.status.should eq(500)
      data = parse_json(last_response.body)
      data.should be_a Hash
      data.should_not be_empty
      data['error'].should_not be_nil
      data['error']['message'].should eq('Something went wrong')
      data['error']['type'].should eq('RuntimeError')
    end
  end
end