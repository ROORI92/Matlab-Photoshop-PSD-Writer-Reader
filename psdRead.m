function outputStructure = psdRead(inputFile)
%------------------------------- Function Header -------------------------------
%
% Function Name:
%   psdWrite
%
% Description:
%   Produces a PSD file containing the input images as layers.
%
% Syntax:
%   psdWrite(inputFolderName, outputFileName);
%
% Inputs:
%   inputFolderName - Name or path of the folder which contains the images. If 
%                      name is given then folder must be located in the same 
%                      directory as the function.
%   outputFileName  - Name or path of the output PSD file.
%
% Example: 
%   psdWrite("images", "output");
%
% License:
%   Copyright (C) {{ 2019 }} {{ Ramzi Theodory and Serina Giha }}
%   This program is free software: you can redistribute it and/or modify
%   it under the terms of the GNU Affero General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
%
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU Affero General Public License for more details.
%
%   You should have received a copy of the GNU Affero General Public License
%   along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
% Authors: 
%   Ramzi Theodory and Serina Giha
%
% Last revision:
%   14. February 2019
%
%---------------------------------- Begin Code ---------------------------------

% Check if Octave or Matlab
if exist('OCTAVE_VERSION', 'builtin') ~= 0
  if (length(regexp(inputFile, ".*\.psd$"))==0)
    inputFile = strcat(inputFile, '.psd');
  end
else
  if ~endsWith(inputFile, '.psd', 'IgnoreCase', true)
    inputFile = strcat(inputFile, '.psd');
  end
end

% Open the file (ieee big-endian ordering)

fid = fopen(inputFile, 'r', 'ieee-be');

header.FormatSignature= fread(fid, 4, 'uint8=>char');

if (~isequal(header.FormatSignature', '8BPS'))
    fclose(fid);
    error('Format signature mismatch (%s).', header.FormatSignature);
end

header.FormatVersion = fread(fid, 1, 'uint16');

if (header.FormatVersion ~= 1)
    fclose(fid);
    error('Bad PSD version number (%d).',header.FormatVersion)
end

fseek(fid, 6, 'cof');

header.numSamples = fread(fid, 1, 'uint16');
header.rows = fread(fid, 1, 'uint32');
header.columns = fread(fid, 1, 'uint32');
header.bitsPerSample = fread(fid, 1, 'uint16');
header.colorMode = fread(fid, 1, 'uint16');

%read Color Mode data, Image Resources...

blockLength = fread(fid, 1, 'uint32');

header.colorModeData.blockLength = blockLength;

if (blockLength > 0)
    header.colorModeData.data = fread(fid, blockLength, 'uint8=>uint8');
else
    header.colorModeData.data = [];
end

blockLength = fread(fid, 1, 'uint32');

header.imageResources.length = blockLength;

if (blockLength > 0)
    header.imageResources.data = fread(fid, blockLength, 'uint8=>uint8');
else
    header.imageResources.data = [];
end

%Read layers and masks....
layersAndMasks.length = fread(fid, 1, 'uint32');
layersAndMasks.layerInfoLength = fread(fid, 1, 'uint32');
layersAndMasks.layerCount = fread(fid, 1, 'uint16');

layerCount = layersAndMasks.layerCount;

for i = 1:layerCount
    layer = ['layer' num2str(i)];
    layersAndMasks.(layer).layerRecords.rectangle = fread(fid, 4, 'uint32');
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
        
    fseek(fid, extraDataLength, 'cof'); %skip extra data
end

compression = fread(fid, 1, 'uint16');

%Reading the layers
layerImages = cell(1, layerCount);

tempImg = cell(1, header.numSamples);

for i = 1:layerCount
    tempImg{1} = uint8(zeros(header.columns, header.rows));
    tempImg{2} = uint8(zeros(header.columns, header.rows));
    tempImg{3} = uint8(zeros(header.columns, header.rows));
    
    finalImg = uint8(zeros(header.columns, header.rows, header.numSamples));
    
    for j = 1: header.numSamples
        scanlineLengths = fread(fid, header.rows, 'uint16');
        
        for p = 1:numel(scanlineLengths)
            idx = (p - 1) * header.columns + 1;
            tempImg{j}(idx:(idx + header.columns - 1)) = decodeScanline(fid, scanlineLengths(p), header);
        end
        
        fseek(fid, 2 , 'cof'); 
    end
    
    finalImg(:, :, 1) = tempImg{1};
    finalImg(:, :, 2) = tempImg{2};
    finalImg(:, :, 3) = tempImg{3};
    
    finalImg = reshape(finalImg, [header.columns, header.rows, header.numSamples]);
    finalImg = permute(finalImg, [2 1 3]);
    
    layerImages{i} = finalImg;
end

outputStructure.metadata.header = header;
outputStructure.metadata.layersInformation = layersAndMasks;
outputStructure.layerImages = layerImages;

fclose(fid);
end

function buffer = decodeScanline(fid, scanlineLength, metadata)
%READRLE  Read and decode an RLE scanline.
buffer(metadata.columns, 1) = uint8(0);
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