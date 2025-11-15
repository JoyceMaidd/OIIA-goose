#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>
#include <span>
#include <stdexcept>
#include <vector>

struct BitmapFileHeader
{
    std::uint32_t size;
    std::uint32_t reserved;
    std::uint32_t bitsOffset;
};

struct BitmapInfoHeader
{
    std::uint32_t size;
    std::int32_t width;
    std::int32_t height;
    std::uint16_t planes;
    std::uint16_t bitCount;
    std::uint32_t compression;
    std::uint32_t imageSize;
    std::int32_t xPelsPerMeter;
    std::int32_t yPelsPerMeter;
    std::uint32_t colorUsed;
    std::uint32_t colorsImportant;
};

class Bitmap
{
public:
    explicit Bitmap(const char *filename)
        : m_filename(filename)
    {
        std::ifstream file;
        file.exceptions(std::ifstream::badbit | std::ifstream::failbit);
        file.open(filename, std::ifstream::in | std::ifstream::binary);

        std::array<char, 2> signature;
        file.read(signature.data(), signature.size());
        if (signature[0] != 'B' || signature[1] != 'M')
        {
            throw std::invalid_argument("Invalid bitmap");
        }

        BitmapFileHeader fileHeader;
        file.read(reinterpret_cast<char *>(&fileHeader), sizeof(fileHeader));

        BitmapInfoHeader infoHeader;
        file.read(reinterpret_cast<char *>(&infoHeader), sizeof(infoHeader));

        // Support 24-bit (uncompressed) and 32-bit (with optional BI_BITFIELDS)
        if (infoHeader.height < 0)
        {
            throw std::invalid_argument("Negative height not supported");
        }

        m_width = static_cast<unsigned int>(infoHeader.width);
        m_height = static_cast<unsigned int>(infoHeader.height);

        std::uint32_t bitCount = infoHeader.bitCount;
        std::uint32_t compression = infoHeader.compression;

        if (!(bitCount == 24 || bitCount == 32))
        {
            throw std::invalid_argument("Only 24-bit or 32-bit bitmaps supported, bit count: " + std::to_string(bitCount));
        }

        // Default masks for little-endian B G R order in 32-bit BI_RGB
        std::uint32_t redMask = 0x00FF0000u;
        std::uint32_t greenMask = 0x0000FF00u;
        std::uint32_t blueMask = 0x000000FFu;

        if (bitCount == 32 && compression == 3)
        {
            // BI_BITFIELDS: next 3 DWORDs define red, green, blue masks
            std::uint32_t masks[3];
            file.read(reinterpret_cast<char *>(masks), sizeof(masks));
            redMask = masks[0];
            greenMask = masks[1];
            blueMask = masks[2];
        }

        // Precompute shifts and widths for masks (used for BI_BITFIELDS)
        auto mask_shift = [](std::uint32_t mask)
        {
            int s = 0;
            if (mask == 0)
                return 0;
            while ((mask & 1u) == 0u)
            {
                mask >>= 1;
                ++s;
            }
            return s;
        };
        auto mask_width = [](std::uint32_t mask)
        {
            int w = 0;
            while (mask)
            {
                w += (mask & 1u);
                mask >>= 1;
            }
            return w;
        };

        m_redMask = redMask;
        m_greenMask = greenMask;
        m_blueMask = blueMask;
        m_redShift = mask_shift(redMask);
        m_greenShift = mask_shift(greenMask);
        m_blueShift = mask_shift(blueMask);
        m_redWidth = mask_width(redMask);
        m_greenWidth = mask_width(greenMask);
        m_blueWidth = mask_width(blueMask);

        // Compute bytes per pixel and scanline width in bytes (BMP scanlines are 4-byte aligned)
        unsigned int bytesPerPixel = static_cast<unsigned int>(bitCount / 8);
        auto widthInBytes = m_width * bytesPerPixel;
        if (widthInBytes % 4 != 0)
        {
            widthInBytes += 4 - widthInBytes % 4;
        }

        std::vector<std::uint8_t> line;
        line.resize(widthInBytes);

        m_pixels.resize(m_width * m_height);

        file.seekg(fileHeader.bitsOffset, std::ifstream::beg);

        for (unsigned int y = 0; y != m_height; ++y)
        {
            file.read(reinterpret_cast<char *>(line.data()), line.size());

            for (unsigned int x = 0; x != m_width; ++x)
            {
                if (bytesPerPixel == 3)
                {
                    // 24-bit BMP: B G R
                    auto b = line[x * 3 + 0];
                    auto g = line[x * 3 + 1];
                    auto r = line[x * 3 + 2];
                    m_pixels[(m_height - y - 1) * m_width + x] = toRgb222(r, g, b);
                }
                else // 4 bytes per pixel
                {
                    auto off = x * 4u;
                    // assemble little-endian 32-bit pixel value
                    std::uint32_t pixel = static_cast<std::uint32_t>(line[off]) | (static_cast<std::uint32_t>(line[off + 1]) << 8) | (static_cast<std::uint32_t>(line[off + 2]) << 16) | (static_cast<std::uint32_t>(line[off + 3]) << 24);

                    std::uint8_t r8, g8, b8;
                    if (compression == 3)
                    {
                        auto rval = (pixel & m_redMask) >> m_redShift;
                        auto gval = (pixel & m_greenMask) >> m_greenShift;
                        auto bval = (pixel & m_blueMask) >> m_blueShift;

                        auto scale_to_8 = [](std::uint32_t v, int w) -> std::uint8_t
                        {
                            if (w <= 0)
                                return 0;
                            std::uint32_t maxv = (w >= 32) ? 0xFFFFFFFFu : ((1u << w) - 1u);
                            return static_cast<std::uint8_t>((v * 255 + maxv / 2) / maxv);
                        };

                        r8 = scale_to_8(rval, m_redWidth);
                        g8 = scale_to_8(gval, m_greenWidth);
                        b8 = scale_to_8(bval, m_blueWidth);
                    }
                    else
                    {
                        // BI_RGB 32-bit: assume bytes are B G R A
                        b8 = line[off + 0];
                        g8 = line[off + 1];
                        r8 = line[off + 2];
                    }

                    m_pixels[(m_height - y - 1) * m_width + x] = toRgb222(r8, g8, b8);
                }
            }
        }
    }

    constexpr unsigned int width() const noexcept
    {
        return m_width;
    }

    constexpr unsigned int height() const noexcept
    {
        return m_height;
    }

    constexpr std::span<const std::uint8_t> pixels() const noexcept
    {
        return m_pixels;
    }

    constexpr std::uint8_t pixel(unsigned int x, unsigned int y) const
    {
        if (x >= m_width || y >= m_height)
        {
            throw std::invalid_argument("Out of range");
        }
        return m_pixels[y * m_width + x];
    }

    constexpr const std::filesystem::path &filename() const noexcept
    {
        return m_filename;
    }

private:
    // Convert 8-bit per-channel RGB to packed RGB222 (2 bits per channel).
    // Uses nearest rounding so we pick the closest of the 64 colors.
    static constexpr std::uint8_t toRgb222(std::uint8_t r, std::uint8_t g, std::uint8_t b) noexcept
    {
        auto quant = [](std::uint8_t v) -> std::uint8_t
        {
            return static_cast<std::uint8_t>((static_cast<unsigned int>(v) * 3u + 127u) / 255u);
        };
        return static_cast<std::uint8_t>((quant(r) << 4) | (quant(g) << 2) | quant(b));
    }

    // Masks/shifts/widths used when reading 32-bit BI_BITFIELDS images
    std::uint32_t m_redMask = 0x00FF0000u;
    std::uint32_t m_greenMask = 0x0000FF00u;
    std::uint32_t m_blueMask = 0x000000FFu;
    int m_redShift = 16;
    int m_greenShift = 8;
    int m_blueShift = 0;
    int m_redWidth = 8;
    int m_greenWidth = 8;
    int m_blueWidth = 8;

    unsigned int m_width = 0;
    unsigned int m_height = 0;
    std::filesystem::path m_filename;
    std::vector<std::uint8_t> m_pixels;
};

class BitmapMaker
{
public:
    using PixelSet = std::array<std::uint8_t, 4>;

    void analyze(const Bitmap &bitmap)
    {
        constexpr std::size_t groupSize = 4u;
        if (bitmap.width() % groupSize != 0)
        {
            throw std::invalid_argument("Bitmap width must be divisible by 4");
        }

        for (unsigned int y = 0; y != bitmap.height(); ++y)
        {
            PixelSet pixelSet;
            for (unsigned int x = 0; x != bitmap.width(); x += pixelSet.size())
            {
                for (std::size_t i = 0; i != pixelSet.size(); ++i)
                {
                    pixelSet[i] = bitmap.pixel(x + i, y);
                }

                auto res = m_pixelSetHistogram.insert({pixelSet, 1});
                if (!res.second)
                {
                    res.first->second++;
                }
            }
        }
    }

    void createPalette()
    {
        if (m_pixelSetHistogram.size() > 64)
        {
            throw std::runtime_error("Got more than 64 pixel sets");
        }

        std::vector<std::pair<PixelSet, unsigned int>> sortedPixelSets;
        sortedPixelSets.assign(m_pixelSetHistogram.begin(), m_pixelSetHistogram.end());
        std::sort(sortedPixelSets.begin(), sortedPixelSets.end(), [](const auto &lhs, const auto &rhs)
                  { return rhs.second < lhs.second; });

        for (std::size_t i = 0; i != sortedPixelSets.size(); ++i)
        {
            m_palette[sortedPixelSets[i].first] = static_cast<std::uint8_t>(i);
        }
    }

    void writePalette(const std::filesystem::path &outputDir) const
    {
        auto filename = outputDir / "palette.svh";

        std::ofstream file;
        file.exceptions(std::ofstream::failbit | std::ofstream::badbit);
        file.open(filename.string(), std::ofstream::out | std::ofstream::trunc);

        if (m_palette.empty())
        {
            file << "// empty palette\n";
            return;
        }
        file << "reg [5:0] palette[" << (m_palette.size() - 1) << ":0][" << (PixelSet().size() - 1) << ":0];\n";
        file << "initial begin\n";

        std::vector<PixelSet> palette;
        palette.resize(m_palette.size());
        for (auto [pixelSet, encoding] : m_palette)
        {
            palette.at(encoding) = pixelSet;
        }

        static const std::array<std::string_view, 4> mapping({"00", "01", "10", "11"});
        for (std::size_t i = 0; i != palette.size(); ++i)
        {
            auto pixelSet = palette[i];
            for (std::size_t j = 0; j != pixelSet.size(); ++j)
            {
                auto pixel = pixelSet[j];

                file << "    palette[" << i << "][" << j << "] = 6'b" << mapping.at(pixel >> 4) << mapping.at((pixel >> 2) & 0x03) << mapping.at(pixel & 0x03) << ";\n";
            }
        }

        file << "end\n"
             << std::flush;
    }

    void writeBitmap(const Bitmap &bitmap, const std::filesystem::path &outputDir) const
    {
        auto filename = outputDir / bitmap.filename().filename().replace_extension("svh");

        std::ofstream file;
        file.exceptions(std::ofstream::failbit | std::ofstream::badbit);
        file.open(filename.string(), std::ofstream::out | std::ofstream::trunc);

        auto name = bitmap.filename().filename().replace_extension("").string();

        PixelSet pixelSet;

        file << "reg [5:0] " << name << "[" << (bitmap.width() / pixelSet.size() - 1) << ":0][" << (bitmap.height() - 1) << ":0];\n";
        file << "initial begin\n";

        for (unsigned int y = 0; y != bitmap.height(); ++y)
        {
            for (unsigned int x = 0; x != bitmap.width(); x += pixelSet.size())
            {
                for (std::size_t j = 0; j != pixelSet.size(); ++j)
                {
                    pixelSet[j] = bitmap.pixel(x + j, y);
                }

                file << "    " << name << "[" << (x / pixelSet.size()) << "][" << y << "] = 6'd" << m_palette.at(pixelSet) << ";\n";
            }
        }

        file << "end\n"
             << std::flush;
    }

private:
    std::map<PixelSet, unsigned int> m_pixelSetHistogram;
    std::map<PixelSet, unsigned int> m_palette;
};

int main(int argc, char **argv)
{
    if (argc < 3)
    {
        std::cerr << "Usage: make_bitmaps OUTPUT_DIR FILE [FILE...]" << std::endl;
        return EXIT_FAILURE;
    }

    try
    {
        std::vector<Bitmap> bitmaps;
        for (int i = 2; i != argc; ++i)
        {
            bitmaps.emplace_back(argv[i]);
        }

        std::filesystem::path outputDir = argv[1];

        BitmapMaker bitmapMaker;
        for (const auto &bitmap : bitmaps)
        {
            bitmapMaker.analyze(bitmap);
        }
        bitmapMaker.createPalette();
        bitmapMaker.writePalette(outputDir);
        for (const auto &bitmap : bitmaps)
        {
            bitmapMaker.writeBitmap(bitmap, outputDir);
        }
        return EXIT_SUCCESS;
    }
    catch (const std::exception &exception)
    {
        std::cerr << "Caught exception: " << exception.what() << std::endl;
        return EXIT_FAILURE;
    }
}