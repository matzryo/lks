
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

class AddressSearch
  MAX_SIZE = 1024**2*100 # 100MiB
  ZIP_URL = "http://www.post.japanpost.jp/zipcode/dl/kogaki/zip/ken_all.zip"
  CSV_ORIGINAL_FILENAME = "KEN_ALL.CSV"
  CSV_SHAPED_FILENAME = "KEN_ALL.CSV"
  ZIP_FILENAME = "ken_all.zip"
  INDEX_FILENAME = "ken_all_indexes.dump"
  DATA_DIRECTORY = "data"

  def prepare
    download_zipfile
    unzip
    shape
    create_index
  end

  def search(search_word)
    unless indexed?
      puts "インデックスを作成します。"
      create_index
    end

    # 1文字のときはどうする?
    bi_gram = search_word.each_char.each_cons(2).map(&:join)
    indexes =
        File.open(INDEX_FILENAME) do |io|
          Marshal.load(io)
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

  private

  def download_zipfile
    puts "DL中…"
    File.open(ZIP_FILENAME, "w") do |f|
      data = URI.open(ZIP_URL).read
      f.write data
    end
  end

  def unzip
    puts "解凍中…"
    Zip::File.open(ZIP_FILENAME) do |zip_file|
      # ファイル名指定しちゃっていいのかな
      entry = zip_file.glob(CSV_ORIGINAL_FILENAME).first

      raise 'File too large when extracted' if entry.size > MAX_SIZE

      if File.exist?(CSV_ORIGINAL_FILENAME)
        File.delete(CSV_ORIGINAL_FILENAME)
      end

      entry.extract
    end
  end

  def shape
    puts "整形中…"
    # 文字コード変換
    # 以下に掲載がない場合
    # 次にバンチ
    # 一円
    # 丸括弧
    # 複数行の連結
    # フラグで対応できそう
  end

  def create_index
    puts "インデックス作成中…"
    # メモリ大丈夫かな
    indexes = {}

    CSV.foreach(CSV_SHAPED_FILENAME, encoding: "CP932:UTF-8").with_index do |row, index|
      # 住所の箇所を抜き出して繋げてbi-gram
      bi_gram = row.slice(6..8).join.each_char.each_cons(2).map(&:join)
      bi_gram.each do |word|
        unless indexes.has_key?(word)
          indexes[word] = []
        end
        indexes[word].push(index)
      end
    end
    File.open(INDEX_FILENAME, 'w') do |io|
      Marshal.dump(indexes, io)
    end
  end

  def indexed?
    File.exist?(INDEX_FILENAME)
  end
end

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

address_search = AddressSearch.new

subcommand = ARGV.shift

case subcommand
when "prepare"
  unless ARGV.empty?
    raise ArgumentError, "引数の指定が不正です。"
  end
  address_search.prepare
when "search"
  search_word = ARGV.shift
  unless ARGV.empty?
    raise ArgumentError, "引数の指定が不正です。"
  end
  address_search.search(search_word)
else
  help
end
