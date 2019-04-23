# Concepts and original code taken from https://github.com/jstrait/nanosynth

require "wavefile"

class AudioGenerator
  def initialize(settings = {})
    # The frequency of the tone generated - 440.0 is 440Hz, or Middle-A
    @frequency = settings[:frequency] || 440.0

    # A float from 0.0 to 1.0, effectively representing the volume of the tone
    @max_amplitude = settings[:max_amplitude] || 0.5

    # The number of samples per second, typically 44100 or 48000Hz
    @sample_rate = settings[:sample_rate] || 44_100

    # The length of the sample in seconds
    @length_in_seconds = settings[:length_in_seconds] || 1
  end

  # Generates a single tone and saves it in WAV format
  def generate_wav(output_filename, bit_depth: 16, channels: :stereo)
    # Wrap the array of samples in a Buffer, so that it can be written to a
    # Wave file by the WaveFile gem. Since we generated samples between -1.0
    # and 1.0, the sample type should be :float
    wave_format = WaveFile::Format.new(:mono, :float, @sample_rate)
    buffer = WaveFile::Buffer.new(generate_sample_data, wave_format)

    # Write the Buffer containing our samples to a monophonic Wave file
    bit_depth_option = "pcm_#{bit_depth}".to_sym
    wave_format = WaveFile::Format.new(channels, bit_depth_option, @sample_rate)
    WaveFile::Writer.new(output_filename, wave_format) do |writer|
      writer.write(buffer)
    end
  end

  private

  # Generates the actual sample data for the audio
  def generate_sample_data
    num_samples = @sample_rate * @length_in_seconds
    position_in_period = 0.0
    position_in_period_delta = @frequency / @sample_rate

    # Initialize an array of samples set to 0.0. Each sample will be replaced
    # with an actual value below.
    samples = [].fill(0.0, 0, num_samples)

    num_samples.times do |i|
      # Add next sample to sample list. The sample value is determined by
      # plugging position_in_period into the appropriate wave function.
      samples[i] = Math.sin(position_in_period * 2 * Math::PI) * @max_amplitude
      position_in_period += position_in_period_delta

      # Constrain the period between 0.0 and 1.0. That is, keep looping and
      # re-looping over the same period.
      position_in_period -= 1.0 if position_in_period >= 1.0
    end

    samples
  end
end
