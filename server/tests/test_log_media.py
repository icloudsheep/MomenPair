from io import BytesIO

import pytest
from PIL import Image

from momen_pair.modules.logs.media_service import InvalidImageError, process_image


def test_log_image_is_resized_and_reencoded_as_webp() -> None:
    source = BytesIO()
    Image.new("RGB", (3200, 1600), color=(120, 80, 200)).save(source, format="JPEG")

    result = process_image(source.getvalue())

    assert result.content_type == "image/webp"
    assert (result.width, result.height) == (2560, 1280)
    assert len(result.content) < len(source.getvalue())
    with Image.open(BytesIO(result.content)) as output:
        assert output.format == "WEBP"


def test_log_image_rejects_non_image_content() -> None:
    with pytest.raises(InvalidImageError):
        process_image(b"not-an-image")
