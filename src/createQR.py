import qrcode
from qrcode import constants
import sys
from PIL import ImageDraw, ImageFont
import os
import argparse

# CONFIG
error_correction = constants.ERROR_CORRECT_H  # high error correction

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="QR chunk generator")
    parser.add_argument("key_path", help="Path to the key file")
    parser.add_argument("-f", "--font", help="Path to font file (optional)")
    parser.add_argument("-o", "--output", help="Output directory (optional)")
    parser.add_argument("-s", "--size", help="Chunk size (optional)")

    args = parser.parse_args()

    key_path = sys.argv[1]
    font_path = args.font
    output_dir = args.output
    if output_dir is None:
        output_dir = "qr_chunks"
    chunk_size = int(args.size)
    if chunk_size is None:
        chunk_size = 512

    if not os.path.isfile(key_path):
        print(f"Error: Key file path '{key_path}' does not exist.")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    with open(key_path, "r") as f:
        data = f.read()

    chunks = [data[i:i+chunk_size] for i in range(0, len(data), chunk_size)]
    total_chunks = len(chunks)
    print(f"Total chunks: {total_chunks}")

    for idx, chunk in enumerate(chunks, start=1):
        qr = qrcode.QRCode(
            version=None,
            error_correction=error_correction,
            box_size=10,
            border=4
        )
        qr.add_data(chunk)
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")

        if font_path:
            draw = ImageDraw.Draw(qr_img)
            text = f"{idx}/{total_chunks}"

            font_size = qr_img.size[0] // 16
            font = ImageFont.truetype(font_path, font_size)

            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
            x = (qr_img.size[0] - text_width) // 2
            y = (qr_img.size[1] - text_height) // 2

            # White rectangle behind number
            padding = 10
            rect_x0 = x - padding
            rect_y0 = y - padding
            rect_x1 = x + text_width + padding
            rect_y1 = y + text_height + padding
            draw.rectangle([rect_x0, rect_y0, rect_x1, rect_y1], fill="white")

            shift_upwards = -12
            text_x = rect_x0 + (rect_x1 - rect_x0 - text_width) // 2
            text_y = rect_y0 + shift_upwards + (rect_y1 - rect_y0 - text_height) // 2
            draw.text((text_x, text_y), text, fill="black", font=font)

        # Save
        out_path = os.path.join(output_dir, f"qr_chunk_{idx:01d}.png")
        qr_img.save(out_path)
        print(f"Saved {out_path}")
