package.path = './LuaImage/?.lua;' .. package.path
require('nacstern')

-- READ HEXBYTE
local function read_hbform(str, pos) -- READ PNG FORMAT
  local a, b, c, d = str:byte(pos, pos + 3)
  return ((a << 24) | (b << 16) | (c << 8) | d)
end

-- INPUT HEXBYTE
local function write_hbform(input)
  if type(input) == "number" then
    return string.char((input >> 24) & 0xFF, (input >> 16) & 0xFF, (input >> 8) & 0xFF, input & 0xFF)
  elseif type(input) == "string" then
    assert(#input == 4, "String input must be exactly 4 characters")
    local a, b, c, d = input:byte(1, 4)
    local n = ((a << 24) | (b << 16) | (c << 8) | d)
    return string.char((n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF)
  else
    error("Unsupported input type for write_hbform: must be number or 4-character string")
  end
end

-- GENERATE CRC
local function crc32(str) -- LAST 4 Digits to match PNG chunk format 
  local crc = 0xFFFFFFFF
  for i = 1, #str do
    crc = crc ~ str:byte(i)
    for _ = 1, 8 do
      if crc & 1 == 1 then
        crc = (crc >> 1) ~ 0xEDB88320
      else
        crc = crc >> 1
      end
    end
  end
  return (~crc) & 0xFFFFFFFF
end
local function pad_png_to_target_size(png_path, output_path)
  local f = assert(io.open(png_path, "rb"))
  local data = f:read("*all")
  f:close()

  local current_size = #data
  local target_size

  if current_size >= 40 * 1024 then
    -- Random target between 40 KB and 80 KB
    target_size = math.random(40 * 1024 + 1, 80 * 1024)
  else
    target_size = 50 * 1024
  end

  local pad_size = target_size - current_size
  if pad_size <= 0 then
    print("No padding needed. File already exceeds target.")
    return
  end

  -- Generate random hexbytes (4-byte aligned)
  local pad = {}
  for i = 1, pad_size do
    pad[i] = string.char(math.random(0, 255))
  end

  local padded_data = data .. table.concat(pad)
  local out = assert(io.open(output_path, "wb"))
  out:write(padded_data)
  out:close()

  print(string.format("Padding complete: added %d bytes to reach %d KB\n", pad_size, math.floor(target_size / 1024)))
end
pad_png_to_target_size("input.png", "output1.png")

--EMBED PAYLOAD
function embedpayload(png_path, output_path, message, pin)
  local f = assert(io.open(png_path, "rb"))
  local data = f:read("*all")
  f:close()

  local pos = 9
  local insert_pos = nil
  while pos < #data do
    local length = read_hbform(data, pos)
    local chunk_type = data:sub(pos + 4, pos + 7)
    if chunk_type == "tRNS" then
      insert_pos = pos
      break
    end
    pos = pos + 12 + length
  end
  --if not insert_pos then error("No tRNS chunk found to insert before.") end

  local chunk_type = "tEXt"
  local encrypted = encrypt_string(message, secret)
  local payload = pin .. "\0" .. encrypted.encrypted_stream
  local length = #payload
  local crc = crc32(chunk_type .. payload)

  local chunk = write_hbform(length) .. chunk_type .. payload .. write_hbform(crc)
  local output = data:sub(1, insert_pos - 1) .. chunk .. data:sub(insert_pos)
  output = output .. write_hbform(insert_pos - 1) .. write_hbform(#chunk) .. write_hbform(pin) .. write_hbform(crc)

  local out = assert(io.open(output_path, "wb"))
  out:write(output)
  out:close()
  print("Embedding complete\n")
end

io.write("Secret: ")
secret = io.read()
secret = 1334472421
embedpayload("output1.png", "output_embedded.png", "GENERIC TESTING, ANTEATER EATING ANTS. HERE COMES THE BEEEEEMO", "BUGS")

function extract_and_validate(png_path)
  local f = assert(io.open(png_path, "rb"))
  local data = f:read("*all")
  f:close()

  local offset       = read_hbform(data, #data - 15)
  --local length       = read_hbform(data, #data - 11)
  --local code_hex     = read_hbform(data, #data - 7)
  --local expected_crc = read_hbform(data, #data - 3)


  local segment = data:sub(offset + 1, offset + length)
  local chunk_type_val = read_hbform(segment, 5)
  local chunk_type_str = string.char(
    (chunk_type_val >> 24) & 0xFF,
    (chunk_type_val >> 16) & 0xFF,
    (chunk_type_val >> 8) & 0xFF,
    chunk_type_val & 0xFF
  )
  --[[ DEBUGGING
  if chunk_type_str ~= "tEXt" then
    error("Chunk type mismatch: expected 'tEXt', got '" .. chunk_type_str .. "'")
  end
  
  local marker_val = read_hbform(segment, 9)
  if marker_val ~= code_hex then
    error(string.format("PIN marker mismatch: expected %08X, got %08X", code_hex, marker_val))
  end

  local actual_crc = read_hbform(segment, length - 3)
  if actual_crc ~= expected_crc then
    error(string.format("CRC mismatch: expected %08X, got %08X", expected_crc, actual_crc))
  end
  ]]--

  local encrypted_stream = segment:sub(14, length - 4)
  for i = 1, #encrypted_stream, 4 do
    local chunk = encrypted_stream:sub(i, i + 3)
    io.write(decrypt_byte(chunk, secret))
  end
  print("\nExtraction complete")
end

extract_and_validate("output_embedded.png")
