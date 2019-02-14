# Matlab-PSD-Writer-Reader
Two Matlab functions which make it possible to write a layered Photoshop PSD files from a folder of input images, or read a PSD file and extract the layers to the Matlab workspace.

## PSD Write

```psdWrite(inputFolder, outputFile);```

### Inputs:

- inputFolder is the name or path of the folder which contains the images. If name is given then folder must be located in the same directory as the function.

- outputFile is the name or path of the output PSD file.

This function will produce a photoshop psd file called: "output.psd" which contains the input images as layers.

### Examples: 
- `psdWrite("images", "output");` Here "images" is a folder in the current directory, and "output.psd" will also be created in the current directory.
- `psdWrite("C:\Users\USER\Downloads\images", "C:\Users\USER\Downloads\output");`

## PSD Read

```psdRead(inputFile);```

### Inputs:

- inputFile is the name or path of the input PSD file.

This function will read the input psd file and extract the layer images and metadata into the Matlab workspace.

### Examples: 
- `psdRead("input.psd");` Here "input.psd" is a psd file in the current directory.
- `psdRead("C:\Users\USER\Downloads\input.psd");`
