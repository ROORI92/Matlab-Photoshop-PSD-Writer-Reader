function outputStructure = psdRead(inputFile)
%------------------------------- Function Header -------------------------------
%
% Function Name:
%   psdRead
%
% Description:
%   Reads a PSD file and extracts metadata and layers to workspace.
%
% Syntax:
%   psdRead(inputFile);
%
% Inputs:
%   inputFile - Name or path of the input PSD file.
%
% Outputs:
%   outputStructure - Structure where metadata and layers are stored
%
% Examples: 
%   output = psdRead("input.psd");
%   output = psdRead("C:\Users\USER\Downloads\input.psd");
%
%---------------------------------- Begin Code ---------------------------------

tic;
data.fid = openFile(inputFile);
data = readHeader(data);
data = readLayerInfo(data);
data = readLayerImages(data);
data = readCompositeImage(data);
outputStructure = getOutputStructure(data);
fclose(data.fid);

fprintf("Read Successful! Elapsed Time: %d seconds\n", toc);
end


function outputStructure = getOutputStructure(data)
header = data.header;
layersAndMasks = data.layersAndMasks;
layerImages = data.layerImages;
compositeImage = data.compositeImage; 

fprintf("Arranging Data in Output Structure...");
outputStructure.metadata.header = header;
outputStructure.metadata.layersInformation = layersAndMasks;
outputStructure.layerImages = layerImages;
outputStructure.compositeImage = compositeImage;

fprintf(" Done\n");
end

function data = readCompositeImage(data)
fid = data.fid;
header = data.header;

fprintf("Reading Composite Image...");
compositeImage = decodeCompositeImage(fid, header);
fprintf(" Done\n");

data.compositeImage = compositeImage;
end

function data = readLayerImages(data)
fid = data.fid;
layerCount = data.layerCount;
header = data.header;
rectangles = data.rectangles;

compression = fread(fid, 1, 'uint16');

if (compression ~= 1)
    fclose(fid);
    error('Unsupported Compression Format (%d).', compression);
end

fprintf("Reading Layers...");

%Reading the layers
layerImages = cell(1, layerCount);

tempImg = cell(1, header.numSamples);

for i = 1:layerCount
    currentRows = rectangles{i}(3);
    currentColumns = rectangles{i}(4);
 
    tempImg{1} = uint8(zeros(currentColumns, currentRows));
    tempImg{2} = uint8(zeros(currentColumns, currentRows));
    tempImg{3} = uint8(zeros(currentColumns, currentRows));
    
    finalImg = uint8(zeros(currentColumns, currentRows, header.numSamples));
    
    for j = 1: header.numSamples
        scanlineLengths = fread(fid, currentRows, 'uint16');
        
        for p = 1:numel(scanlineLengths)
            idx = (p - 1) * currentColumns + 1;
            tempImg{j}(idx:(idx + currentColumns - 1)) = decodeScanline(fid, scanlineLengths(p), currentColumns);
        end
        
        fseek(fid, 2 , 'cof'); 
    end
    
    finalImg(:, :, 1) = tempImg{1};
    finalImg(:, :, 2) = tempImg{2};
    finalImg(:, :, 3) = tempImg{3};
    
    finalImg = reshape(finalImg, [currentColumns, currentRows, header.numSamples]);
    finalImg = permute(finalImg, [2 1 3]);
    
    layerImages{i} = finalImg;
end

data.layerImages = layerImages;

fprintf(" Done\n");
end

function data = readLayerInfo(data)
fid = data.fid;
fprintf("Reading Layers and Masks Data...");

% Read layers and masks....
layersAndMasks.length = fread(fid, 1, 'uint32');
layersAndMasks.layerInfoLength = fread(fid, 1, 'uint32');
layersAndMasks.layerCount = fread(fid, 1, 'uint16');

layerCount = layersAndMasks.layerCount;

for i = 1:layerCount
    layer = ['layer' num2str(i)];
    rectangles{i} = fread(fid, 4, 'uint32');
    layersAndMasks.(layer).layerRecords.rectangle = rectangles{i};
    layersAndMasks.(layer).layerRecords.numChannels = fread(fid, 1, 'uint16');
    
    numChannels = layersAndMasks.(layer).layerRecords.numChannels;
    
    layersAndMasks.(layer).layerRecords.channelInfo = fread(fid, 6*numChannels , 'uint8');      % might be changed (6 *numof Channels)
    layersAndMasks.(layer).layerRecords.blendSig = fread(fid, 4, 'uint8=>char');
    layersAndMasks.(layer).layerRecords.blendKey = fread(fid, 4, 'uint8=>char');
    layersAndMasks.(layer).layerRecords.opacity = fread(fid, 1, 'uint8');
    layersAndMasks.(layer).layerRecords.clipping = fread(fid, 1, 'uint8');
    layersAndMasks.(layer).layerRecords.flags = fread(fid, 1, 'uint8');
    layersAndMasks.(layer).layerRecords.filler = fread(fid, 1, 'uint8');
    layersAndMasks.(layer).layerRecords.extraDataLength = fread(fid, 1, 'uint32');
    
    extraDataLength = layersAndMasks.(layer).layerRecords.extraDataLength;
        
%     fseek(fid, extraDataLength, 'cof'); %skip extra data
    
    LayerMaskDataSize=fread(fid,1,'uint32');
    fseek(fid, LayerMaskDataSize, 'cof'); %skip Layer mask data
    LayerBlendingRanges=fread(fid,1,'uint32');
    fseek(fid, LayerBlendingRanges, 'cof'); %skip Layer Blending Ranges

    name_whole=fread(fid,extraDataLength-LayerMaskDataSize-LayerBlendingRanges-2*4,'uint8=>char').'; % read whole layer name block
    layer_name = name_whole(2:regexp(name_whole,'8BIM')-1); % get just the non-Unicode part with skipping an empty byte (to define length of string?)- not thorougly tested
    layersAndMasks.(layer).layerRecords.Name=layer_name;
    if isempty(layer_name)
        layersAndMasks.(layer).layerRecords.Name=name_whole;
        warning(['The name of ' (layer) ' was not parsed successfully.'])
    end
end

data.rectangles = rectangles;
data.layersAndMasks = layersAndMasks;
data.layerCount = layerCount;

fprintf(" Done\n"); 
end

function data = readHeader(data)
fid = data.fid;

fprintf("Reading Header Information...");

header.FormatSignature= fread(fid, 4, 'uint8=>char');

if (~isequal(header.FormatSignature', '8BPS'))
    fclose(fid);
    error('Format signature mismatch (%s).', header.FormatSignature);
end

header.FormatVersion = fread(fid, 1, 'uint16');

if (header.FormatVersion ~= 1)
    fclose(fid);
    error('Bad PSD version number (%d).', header.FormatVersion);
end

fseek(fid, 6, 'cof');

header.numSamples = fread(fid, 1, 'uint16');
header.rows = fread(fid, 1, 'uint32');
header.columns = fread(fid, 1, 'uint32');
header.bitsPerSample = fread(fid, 1, 'uint16');

if (header.bitsPerSample ~= 8)
    fclose(fid);
    error('Unsupported number of bits per sample (%d).', header.bitsPerSample);
end

header.colorMode = fread(fid, 1, 'uint16');

fprintf(" Done\n");

% Read Color Mode data, Image Resources...

fprintf("Reading Color Mode Data...");

blockLength = fread(fid, 1, 'uint32');

header.colorModeData.blockLength = blockLength;

if (blockLength > 0)
    header.colorModeData.data = fread(fid, blockLength, 'uint8=>uint8');
else
    header.colorModeData.data = [];
end

fprintf(" Done\n");

fprintf("Reading Image Resources...");

blockLength = fread(fid, 1, 'uint32');

header.imageResources.length = blockLength;

if (blockLength > 0)
    header.imageResources.data = fread(fid, blockLength, 'uint8=>uint8');
else
    header.imageResources.data = [];
end

fprintf(" Done\n");

data.header = header;
end

function fid = openFile(inputFile)
% Open the file (ieee big-endian ordering)

fprintf("Opening Input File...");

fid = fopen(inputFile, 'r', 'ieee-be');

fprintf(" Done\n");
end

function compositeImage = decodeCompositeImage(fid, header)
compression = fread(fid, 1, 'uint16');

 if (compression)
    
    if (header.bitsPerSample == 1)
        
        compositeImage(header.columns, header.rows, header.numSamples) = logical(0);
        
    elseif (header.bitsPerSample == 8)
        
        compositeImage(header.columns, header.rows, header.numSamples) = uint8(0);
        
    elseif (header.bitsPerSample == 16)
        
        compositeImage(header.columns, header.rows, header.numSamples) = uint16(0);
        
    end
        
    % Read compressed data.
    scanlineLengths = fread(fid, header.rows * header.numSamples, 'uint16');
    
    for p = 1:numel(scanlineLengths)
        
        idx = (p - 1) * header.columns + 1;
        X(idx:(idx + header.columns - 1)) = decodeScanline(fid, scanlineLengths(p), header.columns);
        
    end
   
else
    
    % Read the uncompressed pixels.
    numPixels = header.numSamples * header.rows * header.columns;
    compositeImage = fread(fid, numPixels, sprintf('*uint%d', header.bitsPerSample));
end
% Reshape the pixels.
compositeImage = reshape(compositeImage, [header.columns, header.rows, header.numSamples]);
compositeImage = permute(compositeImage, [2 1 3]);
end

function buffer = decodeScanline(fid, scanlineLength, currentColumns)
%READRLE  Read and decode an RLE scanline.
buffer(currentColumns, 1) = uint8(0);
count = 1;

fpos = ftell(fid);
while ((ftell(fid) - fpos) < scanlineLength)
    lengthByte = fread(fid, 1, 'uint8');
    
    if (lengthByte <= 127)
        % Read lengthByte + 1 values.
        idxStart = count;
        idxEnd = idxStart + lengthByte;
        buffer(idxStart:idxEnd) = fread(fid, lengthByte + 1, 'uint8=>uint8');
    elseif (lengthByte >= 129)
        % Copy the next byte (257 - lengthByte) times.
        idxStart = count;
        idxEnd = idxStart + 257 - lengthByte - 1;
        runVal = fread(fid, 1, 'uint8=>uint8');
        buffer(idxStart:idxEnd) = runVal;
    end
    
    count = idxEnd + 1;
end
end