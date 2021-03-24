# frozen_string_literal: true

require 'bundler'
require 'csv'
require 'optparse'

require './util'

Bundler.require(:default)

options = {
  width: 1920,
  height: 1080
}

option_parser = OptionParser.new do |parser|
  parser.banner = 'Usage: csv2png.rb [options]'
  parser.on('-i INPUT', '--input=INPUT', 'Input CSV file') do |v|
    options[:input] = v
  end
  parser.on('-o OUTPUT', '--output=OUTPUT', 'Output PNG file') do |v|
    options[:output] = v
  end
  parser.on('-w WIDTH', '--width=WIDTH', Integer, 'Output PNG width') do |v|
    options[:width] = v
  end
  parser.on('-h HEIGHT', '--height=HEIGHT', Integer, 'Output PNG height') do |v|
    options[:height] = v
  end
end

option_parser.parse!

if options[:input].nil? || options[:output].nil?
  puts option_parser.help
  return
end

MARGIN = 50

def read_input(filename)
  input = CSV.foreach(filename)
  data = {}
  labels = []

  input.each.with_index do |row, i|
    if i.zero?
      labels = row
      next
    end

    x = row.shift.to_f
    values = row.map(&:to_f)
    data[x] = values
  end

  [labels, data]
end

def draw_axes(output, _labels, _data, options)
  output.line_xiaolin_wu(MARGIN, MARGIN,
                         MARGIN, options[:height] - MARGIN,
                         ChunkyPNG::Color::BLACK)
  output.line_xiaolin_wu(MARGIN, options[:height] - MARGIN,
                         options[:width] - MARGIN, options[:height] - MARGIN,
                         ChunkyPNG::Color::BLACK)
end

def calculate_attributes(data, options)
  xmin = 0.0
  xmax = 0.0
  value_min = 0.0
  value_max = 0.0
  series_count = 0

  data.each do |x, series|
    xmin = x < xmin ? x : xmin
    xmax = x > xmax ? x : xmax

    series_count = series.count > series_count ? series.count : series_count

    series.each do |value|
      value_min = value < value_min ? value : value_min
      value_max = value > value_max ? value : value_max
    end
  end

  colours = (0...series_count).map { |i| ChunkyPNG::Color.from_hsv((i * 360) / series_count, 1, 1) }

  [
    colours,
    scaler(xmin, xmax, MARGIN, options[:width] - MARGIN),
    scaler(value_min, value_max, options[:height] - MARGIN, MARGIN)
  ]
end

def draw_data(output, data, options)
  colours, horizontal_scaler, vertical_scaler = calculate_attributes(data, options)
  data.each_cons(2) do |(x0, series0), (x1, series1)|
    (0...series0.count).each do |i|
      output.line_xiaolin_wu(horizontal_scaler.call(x0).to_i, vertical_scaler.call(series0[i]).to_i,
                             horizontal_scaler.call(x1).to_i, vertical_scaler.call(series1[i]).to_i,
                             colours[i])
    end
  end
end

labels, data = read_input(options[:input])

output = ChunkyPNG::Image.new(options[:width], options[:height], ChunkyPNG::Color::WHITE)

draw_axes(output, labels, data, options)
draw_data(output, data, options)

output.save(options[:output], interlace: true)
