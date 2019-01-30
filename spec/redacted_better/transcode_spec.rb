require 'spec_helper'

describe Transcode do
  describe '.file_is_24bit?' do
    context 'when the file is 24 bit' do
      it 'returns true' do
        info = instance_double('FlacInfo', streaminfo: { 'bits_per_sample' => 24 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_24bit?('path')).to be true
      end
    end

    context 'when the file is not 24 bit' do
      it 'returns false' do
        info = instance_double('FlacInfo', streaminfo: { 'bits_per_sample' => 16 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_24bit?('path')).to be false
      end
    end
  end

  describe '.file_is_multichannel?' do
    context 'when the file is multichannel' do
      it 'returns true' do
        info = instance_double('FlacInfo', streaminfo: { 'channels' => 3 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_multichannel?('path')).to be true
      end
    end

    context 'when the file is not multichannel' do
      it 'returns false' do
        info = instance_double('FlacInfo', streaminfo: { 'channels' => 2 })
        allow(FlacInfo).to receive(:new).and_return(info)

        expect(described_class.file_is_multichannel?('path')).to be false
      end
    end
  end
end
