
# main.rb create-index
# "渋谷": [3, 5, 7]
#
# インデックス作成
# あっても更新、ただし変わってなければ更新しない
# main.rb read file.csv
#
# (中間処理入るも)
#
# 検索
# main.rb search search-word
require 'zip'
require 'byebug'
require 'open-uri'
require 'csv'
require 'json'

MAX_SIZE = 1024**2*100 # 100MiB
ZIP_URL = "http://www.post.japanpost.jp/zipcode/dl/kogaki/zip/ken_all.zip"
CSV_ORIGINAL_FILENAME = "KEN_ALL.CSV"
CSV_SHAPED_FILENAME = "KEN_ALL.CSV"
ZIP_FILENAME = "ken_all.zip"
INDEX_FILENAME = "ken_all_indexes.json"

def download_zipfile
  File.open(ZIP_FILENAME, "w") do |f|
    data = URI.open(ZIP_URL).read
    f.write data
  end
end

# TODO: 複数回実行を考慮する
# ファイル名指定しちゃっていいのかな
def unzip
  "展開"
  Zip::File.open('ken_all.zip') do |zip_file|
    # Handle entries one by one
    zip_file.each do |entry|
      puts "Extracting #{entry.name}"
      raise 'File too large when extracted' if entry.size > MAX_SIZE

      # Extract to file or directory based on name in the archive
      entry.extract

      # Read into memory
      # content = entry.get_input_stream.read
    end

    # Find specific entry
    # entry = zip_file.glob('*.csv').first
    # raise 'File too large when extracted' if entry.size > MAX_SIZE
    # puts entry.get_input_stream.read
  end
end

def shape
  # 文字コード変換
  # 以下に掲載がない場合
  # 次にバンチ
  # 一円
  # 丸括弧
  # 複数行の連結
  # フラグで対応できそう
  puts "整形中"
end

def create_index
  # メモリ大丈夫かな
  indexes = Hash.new{|hash, key| hash[key] = []}

  puts "インデックス作成開始"
  CSV.foreach(CSV_SHAPED_FILENAME, encoding: "CP932:UTF-8").with_index do |row, index|
    # 住所の箇所を抜き出して繋げてbi-gram
    bi_gram = row.slice(6..8).join.each_char.each_cons(2).map(&:join)
    bi_gram.each do |word|
      indexes[word].push(index)
    end
  end
  File.open(INDEX_FILENAME, 'w') do |io|
    # Marshalのほうが速そう
    JSON.dump(indexes, io)
  end
end

def search(search_word)
  # 1文字のときはどうする?
  bi_gram = search_word.each_char.each_cons(2).map(&:join)
  indexes =
      File.open(INDEX_FILENAME) do |io|
        JSON.load(io)
      end
  matched = nil
  bi_gram.each do |two_chars|
    if lines = indexes[two_chars]
      matched ||= Set.new(lines)
      matched = matched & Set.new(lines)
    end
    matched
  end
  csv = File.open(CSV_SHAPED_FILENAME, encoding: "CP932:UTF-8").readlines
  matched.each do |i|
    puts csv[i]
  end
  if matched.empty?
    puts "該当無し"
  end
end

subcommand = ARGV.shift

def help
  help = <<~HELP
    main.rb create-index
    "渋谷": [3, 5, 7]

    インデックス作成
    あっても更新、ただし変わってなければ更新しない
    main.rb read file.csv

    (中間処理入るも)

    検索
    main.rb search search-word
  HELP
  puts help
end

case subcommand
when "create-index"
  unless ARGV.empty?
    raise ArgumentError, "引数の指定が不正です。"
  end
  create_index
when "search"
  search_word = ARGV.shift
  search(search_word)
else
  # それ意外はヘルプを出す。ちょっと適当。
  help
end

# download_zipfile
# unzip

# 整形処理
# shape

# create_index

# search("東京都")