require 'line/bot'
# 感情分析用APIを使用するためのもの
require 'nlpcloud'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  # 音楽リストを定数化
  AUDIO_POSITIVE_LIST = ['https://www.youtube.com/watch?v=TW9d8vYrVFQ','https://www.youtube.com/watch?v=HZd-vLLeSt0']
  AUDIO_NEGATIVE_LIST = ['https://www.youtube.com/watch?v=0kqyGvc_WNA','https://www.youtube.com/watch?v=faf98cNY8A8']

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    }
  end

  def response_audio_url(label, score)
    if label == 'POSITIVE'
      audio_url = score > 0.5 ? AUDIO_POSITIVE_LIST[0] : AUDIO_POSITIVE_LIST[1]

    elsif label == 'NEGATIVE'
      audio_url = score > 0.5 ? AUDIO_NEGATIVE_LIST[0] : AUDIO_NEGATIVE_LIST[1]
    
    # ラベルが想定していた文字列でない場合はエラーとして処理。
    else
      audio_url = 'エラーが発生しました。少し時間を置いてから再度お試しください。'

    end

    return audio_url
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
          line_message = event.message['text']

          client_nlp = NLPCloud::Client.new('distilbert-base-uncased-finetuned-sst-2-english',ENV['NLP_CLOUD_API_KEY'], gpu: false, lang: 'jpn_Jpan')

          # エラーハンドリングを追加
          begin
            response_sentiment = client_nlp.sentiment(line_message)

            # ネガティブかポジティブかの判定と、その際の感情のスコアを変数に格納
            label = response_sentiment['scored_labels'][0]['label']
            score = response_sentiment['scored_labels'][0]['score']

            audio_url = response_audio_url(label, score)

            message = {
              type: 'text',
              text: audio_url
            }

          # 429エラー用の処理
          rescue RestClient::TooManyRequests => e
            error_message = 'API上限に達しました。1時間後に再度お試しください。'
            message = {
              type: 'text',
              text: error_message
            }
          
          # その他のエラー処理用
          rescue => e
            error_message = 'エラーが発生しました。少し時間を置いてから再度お試しください。'
            message = {
              type: 'text',
              text: error_message
            }
          
          end

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
