require "slack"

module Janky
  module ChatService
    class Slack
      Attachment = Struct.new(:fallback, :text, :pretext, :color, :mrkdwn_in, :fields)
      AttachmentField = Struct.new(:title, :value, :short)

      def initialize(settings)
        team = settings["JANKY_CHAT_SLACK_TEAM"]

        if team.nil? || team.empty?
          raise Error, "JANKY_CHAT_SLACK_TEAM setting is required"
        end

        token = settings["JANKY_CHAT_SLACK_TOKEN"]

        if token.nil? || token.empty?
          raise Error, "JANKY_CHAT_SLACK_TOKEN setting is required"
        end

        @client = ::Slack::Client.new(team: team, token: token)
      end

      def speak(message, room_id, options = {})
        if options[:build].present?
          @client.post_message(nil, room_id, {attachments: attachments(message, options[:build])})
        else
          @client.post_message(message, room_id, options)
        end
      end

      def rooms
        @rooms ||= @client.channels.map do |channel|
          Room.new(channel['id'], channel['name'])
        end
      end

      private

      def attachments(fallback, build)
        status = build.green? ? "was successful" : "failed"
        color = build.green? ? "good" : "danger"

        message = "Build #%s of %s/%s %s" % [
          build.number,
          build.repo_name,
          build.branch_name,
          status
        ]

        janky_field = AttachmentField.new("Janky", build.web_url, false)
        commit_field = AttachmentField.new("Commit", "<#{build.commit_url}|#{build.short_sha1}>", true)
        duration_field = AttachmentField.new("Duration", "#{build.duration}s", true)
        fields = [janky_field.to_h, commit_field.to_h, duration_field.to_h]

        [Attachment.new(fallback, message, nil, color, ["text", "title", "fallback"], fields)]
      end
    end
  end

  register_chat_service "slack", ChatService::Slack
end
