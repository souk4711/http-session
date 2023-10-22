class HTTP::Session
  module Features
    HTTP::Options.register_feature(:hsf_auto_inflate, HTTP::Session::Features::AutoInflate)
  end
end
