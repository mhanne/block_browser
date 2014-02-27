class ActionController::Responder

  def to_hex
    return nil  unless resource.respond_to?(:to_payload)
    render text: resource.to_payload.hth
  end

  def to_bin
    return nil  unless resource.respond_to?(:to_payload)
    render text: resource.to_payload
  end

end
