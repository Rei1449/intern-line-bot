require 'line/bot'
# 感情分析用APIを使用するためのもの
require 'nlpcloud'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          # 送られてきたLineのメッセージ
          lineMessage = event.message['text']

          clientNLP = NLPCloud::Client.new('distilbert-base-uncased-finetuned-sst-2-english','9f5a8910ec519948f6f0876c0cc1f1e7aed7b5fc', gpu: false, lang: 'jpn_Jpan')
          response_sentiment = clientNLP.sentiment(lineMessage)

          # レスポンスが返ってきているのかの確認用
          # puts response_sentiment

          # ネガティブかポジティブかの判定と、その際の感情のスコアを変数に格納
          label = response_sentiment['scored_labels'][0]['label']
          score = response_sentiment['scored_labels'][0]['score']
          # 確認用
          # puts label
          # puts score

          # 今回はスコアのみをユーザーに送り返す
          message = {
            type: 'text',
            text: score
          }
          client.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }
    head :ok
  end
end
