class AttachmentOptimizeJob < ApplicationJob
  queue_as :default

  MAX_DIMENSION = 2000

  def perform(attachment_id)
    attachment = ActiveStorage::Attachment.find_by(id: attachment_id)
    return unless attachment
    blob = attachment.blob
    return unless blob&.image?
    return if blob.metadata.to_h["optimized"]

    io_path = nil
    blob.open do |tempfile|
      io_path = optimize_image(tempfile.path, blob.content_type)
    end
    return unless io_path && File.exist?(io_path)

    # Create optimized blob
    new_blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(io_path, "rb"),
      filename: blob.filename,
      content_type: blob.content_type,
      metadata: blob.metadata.merge("optimized" => true)
    )

    record = attachment.record
    name = attachment.name

    if attachment.record.public_send(name).is_a?(ActiveStorage::Attached::Many)
      # Replace this one attachment in the collection
      record.public_send(name).attach(new_blob)
      attachment.purge
    else
      # Replace single attachment
      record.public_send(name).attach(new_blob)
      attachment.purge
    end
  ensure
    File.delete(io_path) if io_path && File.exist?(io_path)
  end

  private
  def optimize_image(path, content_type)
    require "image_processing/mini_magick"
    pipeline = ImageProcessing::MiniMagick.source(path).auto_orient.resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
    if content_type == "image/jpeg"
      pipeline = pipeline.saver(quality: 80, strip: true)
    end
    processed = pipeline.call
    processed.path
  rescue => _e
    nil
  end
end

