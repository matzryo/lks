# README

## このツールについて

住所検索CLIツール。bi-gramインデックスを活用しています。

## 環境要件

Ruby 2.7.0 にて動作確認しました。

## インストール

```bash
bundle install
```

## 使い方

```bash
ruby main.rb prepare # CSVダウンロード、整形、インデクシング
ruby main.rb search SEARCH_WORD # 検索
```
