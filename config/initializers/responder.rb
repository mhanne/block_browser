class ActionController::Responder

  def to_hex
    render text: resource.to_payload.hth
  end

  def to_bin
    render text: resource.to_payload
  end

end
