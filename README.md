# Matlab-PSD-Writer-Reader
Two Matlab functions which make it possible to write a layered Photoshop PSD files from a folder of input images, or read a PSD file and extract the layers to the Matlab workspace.

## PSD Write:

```psdWrite(inputFolder, outputFile);```

### Inputs:

- "inputFolder" is the name or path of the folder which contains the images. If name is given then folder must be located in the same directory as the function.

- "outputFile" is the name or path of the output PSD file.

This function will produce a photoshop PSD file called: "output.psd" which contains the input images as layers.

### Examples: 
- `psdWrite("images", "output");` or `psdWrite("images", "output.psd");` Here "images" is a folder in the current directory, and "output.psd" will also be created in the current directory.
- `psdWrite("C:\Users\USER\Downloads\images", "C:\Users\USER\Downloads\output");` or `psdWrite("C:\Users\USER\Downloads\images", "C:\Users\USER\Downloads\output.psd");`

## PSD Read:

```outputStructure = psdRead(inputFile);```

### Inputs:

- "inputFile" is the name or path of the input PSD file.

### Outputs:

- "outputStructure" is the name of the structure where the extracted data will be stored.

This function will read the input PSD file and extract the layer images and metadata into the Matlab workspace.

### Examples: 
- `output = psdRead("input.psd");` Here "input.psd" is a PSD file in the current directory.
- `output = psdRead("C:\Users\USER\Downloads\input.psd");`

## Limitations:
- Only works with 8-Bit images (if otherwise, the images are converted to 8-Bits).
- Only works with run-length encoded data in the psd file.
- The "psdRead" function is only intended to work with PSD files that are produced by the "psdWrite" function. Many variables in the PSD file format make it difficult to read all PSD files (but feel free to try!).

## Credit:
The psdRead function is inspired by "Adobe Photoshop PSD file reader" by "Jeff Mather", and it was extended in order to read layers.

https://www.mathworks.com/matlabcentral/fileexchange/4730-adobe-photoshop-psd-file-reader
