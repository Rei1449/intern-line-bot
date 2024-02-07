class UnexpectedApiResponseError < StandardError
    def initialize(msg="想定されていたlabelではありませんでした。")
        super(msg)
    end
end
