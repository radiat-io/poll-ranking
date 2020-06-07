require 'optparse'
require 'csv'

# Setup optparse
Options = Struct.new(:event)
args = Options.new

OptionParser.new do |opts|
  opts.banner = "Usage: main.rb [options]"

  opts.on("-eEVENT", "--event=EVENT", "Run Analysis on Specific Event") do |e|
    args.event = e
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if args.event.nil?
  puts 'Please Select An Event.'
  exit
end

# Read the file
file = File.join('.', 'poll-data', "#{args.event}.csv")
csv = CSV.read(file, headers: true)
result = csv[0]

publisher = csv['調查單位'].uniq.sort
publisher.delete('投票結果')
candidates = csv.headers[3..-1]

penalties_sum = Array.new(publisher.length, 0)
penalties_cnt = Array.new(publisher.length, 0)

# Preprocessing

csv.each do |row|
  row['有效樣本'] = row['有效樣本'].gsub(',', '').to_i
  row['調查時間'] = Date.strptime(row['調查時間'], "%Y年%m月%d")
  candidates.each do |candidate|
    row[candidate] = row[candidate].gsub('%', '').to_i / 100.0 unless row[candidate].nil?
  end
end

earliest_date = csv['調查時間'].min
latest_date = csv['調查時間'][1..-1].max
delta_date = (latest_date - earliest_date).to_i
sigma_x = (0.048 / 8) ** (1.0 / delta_date) # 8 * (sigma_x ** delta_date) = 0.048

puts "民調開始日：#{earliest_date}，民調封關日：#{latest_date}"
puts "時間跨度：#{delta_date} 天，σ 收斂指數：#{sigma_x}"

# Calculate Penalties
ground_truth = csv[0]

csv.each do |row|
  next if row['調查單位'] == '投票結果'

  sigma = 8 * (sigma_x ** (row['調查時間'] - earliest_date).to_i)
  error = 1.960 * (sigma / Math.sqrt(1000)) # CI 95%

  total = 0.0
  candidates.each do |candidate|
    total += row[candidate] unless row[candidate].nil?
  end

  i = publisher.index(row['調查單位'])

  candidates.each do |candidate|
    next if row[candidate].nil?
    normalized = row[candidate] / total
    upper = ground_truth[candidate] + error
    lower = ground_truth[candidate] - error
    if row[candidate] > upper
      penalties_sum[i] += (row[candidate] - upper) ** 2
    elsif row[candidate] < lower
      penalties_sum[i] += (row[candidate] - lower) ** 2
    end
  end

  penalties_cnt[i] += 1
end

(0...publisher.length).each do |i|
  next if penalties_cnt[i] < 2

  puts "#{publisher[i]}, #{-Math.log(penalties_sum[i]/(penalties_cnt[i]-1), Math::E)}"
end
