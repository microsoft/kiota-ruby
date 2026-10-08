# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module BackingStoreModels
  # shaped like a model generated with the backing store enabled
  class User
    include MicrosoftKiotaAbstractions::BackedModel

    def initialize
      @backing_store = MicrosoftKiotaAbstractions::BackingStoreFactorySingleton.instance.create_backing_store
    end

    %w[id name business_phones manager colleagues].each do |property|
      define_method(property) { @backing_store.get(property) }
      define_method("#{property}=") { |value| @backing_store.set(property, value) }
    end
  end
end

RSpec.describe MicrosoftKiotaAbstractions::InMemoryBackingStore do
  subject(:store) { described_class.new }

  it 'rejects an empty key' do
    expect { store.set('', 'x') }.to raise_error(ArgumentError)
    expect { store.get(nil) }.to raise_error(ArgumentError)
  end

  it 'gets what was set, once per key' do
    store.set('name', 'Samwel')
    store.set('name', 'Samwel 2')
    expect(store.get('name')).to eq('Samwel 2')
    expect(store.enumerate).to eq([['name', 'Samwel 2']])
  end

  it 'clears every value' do
    store.set('name', 'Samwel')
    store.clear
    expect(store.enumerate).to be_empty
  end

  it 'tracks values set on a new model as changed' do
    store.set('name', 'Samwel')
    store.return_only_changed_values = true
    expect(store.enumerate).to eq([%w[name Samwel]])
  end

  it 'returns only the values changed after initialization when asked to' do
    store.set('name', 'Samwel')
    store.initialization_completed = true
    store.return_only_changed_values = true
    expect(store.get('name')).to be_nil
    expect(store.enumerate).to be_empty

    store.set('name', 'Bill')
    expect(store.get('name')).to eq('Bill')
    expect(store.enumerate).to eq([%w[name Bill]])
  end

  it 'lists the keys changed to nil' do
    store.set('name', 'Samwel')
    store.set('phone', '123')
    store.initialization_completed = true
    store.set('phone', nil)
    expect(store.enumerate_keys_for_values_changed_to_nil).to eq(['phone'])
  end

  it 'calls subscribers on every set until unsubscribed' do
    calls = []
    id = store.subscribe(->(key, old_value, new_value) { calls << [key, old_value, new_value] })
    store.set('name', 'a')
    store.set('name', 'b')
    store.unsubscribe(id)
    store.set('name', 'c')
    expect(calls).to eq([['name', nil, 'a'], %w[name a b]])
  end
end

RSpec.describe 'an in-memory backing store in a model' do
  def read(model)
    model.backing_store.initialization_completed = true
    model
  end

  let(:user) do
    read(BackingStoreModels::User.new.tap do |u|
      u.id = 'u1'
      u.business_phones = ['+1 234']
    end)
  end

  def changed(model)
    model.backing_store.return_only_changed_values = true
    model.backing_store.enumerate.map(&:first)
  ensure
    model.backing_store.return_only_changed_values = false
  end

  it 'tracks a property replaced after reading' do
    user.name = 'Peter'
    expect(changed(user)).to eq(['name'])
  end

  it 'returns a collection grown after reading when only changed values are asked for' do
    user.business_phones << '+1 567'
    user.backing_store.return_only_changed_values = true
    expect(user.business_phones).to eq(['+1 234', '+1 567'])
  end

  it 'tracks an item appended to a collection' do
    user.business_phones << '+1 567'
    expect(changed(user)).to eq(['business_phones'])
    expect(user.business_phones.size).to eq(2)
  end

  it 'tracks a change inside a nested model' do
    manager = read(BackingStoreModels::User.new.tap { |m| m.id = 'm1' })
    user.manager = manager
    read(user)
    manager.name = 'Boss'
    expect(changed(user)).to eq(['manager'])
    expect(changed(manager)).to eq(['name'])
  end

  it 'keeps the edits of a new model attached to a property' do
    manager = BackingStoreModels::User.new.tap { |m| m.name = 'New boss' }
    user.manager = manager
    expect(changed(manager)).to eq(['name'])
  end

  it 'stops following a nested model once it is replaced' do
    old_manager = read(BackingStoreModels::User.new.tap { |m| m.id = 'm1' })
    user.manager = old_manager
    user.manager = read(BackingStoreModels::User.new.tap { |m| m.id = 'm2' })
    read(user)
    old_manager.name = 'Gone'
    expect(changed(user)).to be_empty
    expect(user.manager.id).to eq('m2')
  end

  it 'ignores a detached nested model edited after the store is cleared' do
    manager = read(BackingStoreModels::User.new.tap { |m| m.id = 'm1' })
    user.manager = manager
    user.backing_store.clear
    expect { manager.name = 'Gone' }.not_to raise_error
    expect(user.backing_store.enumerate).to be_empty
  end

  it 'follows a model appended to a collection it already holds' do
    user.colleagues = []
    read(user)
    colleague = read(BackingStoreModels::User.new.tap { |c| c.id = 'c1' })
    user.colleagues << colleague
    expect(changed(user)).to eq(['colleagues'])
    read(user)
    colleague.name = 'Pal'
    expect(changed(user)).to eq(['colleagues'])
  end

  it 'tracks an item replaced in place in a collection' do
    user.business_phones[0] = '+9 999'
    expect(changed(user)).to eq(['business_phones'])
  end

  it 'tracks an item of a collection edited in place' do
    user.business_phones = [+'+1 234']
    read(user)
    user.business_phones[0].replace('+9 999')
    expect(changed(user)).to eq(['business_phones'])
  end

  it 'tracks a collection reordered in place' do
    user.business_phones = ['+1', '+2']
    read(user)
    user.business_phones.reverse!
    expect(changed(user)).to eq(['business_phones'])
  end

  it 'holds a model in its own property' do
    expect { user.manager = user }.not_to raise_error
    read(user)
    user.name = 'Me'
    expect(changed(user)).to contain_exactly('name', 'manager')
  end

  it 'holds two models that reference each other' do
    boss = read(BackingStoreModels::User.new.tap { |m| m.id = 'm1' })
    user.manager = boss
    expect { boss.colleagues = [user] }.not_to raise_error
    read(user)
    read(boss)
    boss.name = 'Boss'
    expect(changed(user)).to eq(['manager'])
    expect(changed(boss)).to contain_exactly('name', 'colleagues')
  end

  it 'tracks a change inside a model in a collection' do
    colleague = read(BackingStoreModels::User.new.tap { |c| c.id = 'c1' })
    user.colleagues = [colleague]
    read(user)
    colleague.name = 'Pal'
    expect(changed(user)).to eq(['colleagues'])
  end
end

RSpec.describe MicrosoftKiotaAbstractions::BackingStoreFactorySingleton do
  after { described_class.instance = nil }

  it 'creates in memory stores by default' do
    expect(described_class.instance.create_backing_store).to be_a(MicrosoftKiotaAbstractions::InMemoryBackingStore)
  end

  it 'uses the factory it is given' do
    custom = Class.new { def create_backing_store = :custom }.new
    described_class.instance = custom
    expect(described_class.instance.create_backing_store).to eq(:custom)
  end
end
