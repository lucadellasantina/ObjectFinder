
## ObjectFinder

<div style="text-align:center"><img src ="https://lucadellasantina.github.io/ObjectFinder/app_icon_big.png" />></div>

##  Recognize 3D structures in image stacks

### What is ObjectFinder?
ObjectFinder is a MATLAB® app that allows you to recognize thousands to millions of small structures within three-dimensional image volumes in a matter of minutes. 

ObjectFinder is specifically developed for neuroscience research, where it can detect fluorescently-labeled synapses in neuronal image stacks acquired using confocal or super-resolution microscopes.

### Free as in Freedom, for everyone, period.
ObjectFinder is licensed under the strong copyleft license GNU General Public License v3.
This licensing approach ensures you will always have the right to obtain ObjectFinder for free, view and modify the source code to review its functionality and improve its features.

We strongly believe that software developed for data analysis in scientific research must have these two fundamental features:
* Be open source to ensure the highest level of reproducibility of your science.
* Be free of charge for everyone, to ensure no cultural divide is built between scientists who can and those who cannot afford expensive software packages to produce meaningful scientific discoveries with their research.

### Tuned for speed
ObjectFinder can search hundred thosands objects in a matter of minutes by taking full advantage of your computer's CPU cores, this is achieved by implementing multi-threaded search inside the 3D volume. On a typical workstation with 8-core CPU this means an 8X fold faster speed compared to a classic app!

### Seamlessly integrates with Bitplane Imaris®
ObjectFinder can display detected objects in Imaris® to take full advantage of its 3D rendering capabilities. You can visually add, remove or filter objects by visual inspection against the original 3D image.

### Create publication-quality figures
Using the "Plot" feature of ObjectFinder, you will be able to generate publication-quality figures of objects density, neuronal skeletons and synaptic distribution along neurites.

### Export results to Microsoft Excel®
Analysis results can be exported to Excel spreadsheets for further elaboration or plotting using your favorite data analysis application.

### How do I use ObjectFinder to find structures in my image?
The semi-automated object recognition process starts with creating a folder structure for your experiment with a base directory called after your experiment. Let's assume your experiment folder's name is "MyExperiment".

1. Install ObjectFinder in matlab's "App" tab by clicking "
1. Create a subfolder called "MyExperiment/I" where you will place all your original image stacks as 3D .tif files (one file per channel).
1. Start ObjectFinder from your MATLAB® Apps list.
1. Click the folder icon to select your experiment folder "MyExperiment"
1. Click "Load Images", the available images will be displayed as x-y projection and you will be asked to tell ObjectFinder which image contains the structures to recognize. Optionally, you can also specify which image contains a binary mask to limit the search.
1. Click "Search Objects" to start the automatic search of objects. Tip: enable the local cluster of cores in MATLAB® (bottom-left icon in your matlab main screen) to go at maximum speed taking full advantage of ObjectFinder's multithreaded search.
1. Click "Filter Objects" to remove candidate objects that are too small (only one plane on Z) and touching the optional mask's border.
1. If you have Bitplane Imaris® 7 installed, you can click on "Inspect 3D" in order to visually inspect and refine detected objects in three dimentions.
1. Click "Calc. Density" to finish the detection process and calculate information about object density in the volume.

### System Requirements
Software:
MATLAB R2016b+
Image Processing Toolbox
Parallel Computing Toolbox
BitPlane Imaris® 7 (optional)

Hardware:
CPU: Intel Core i5+ or Xeon clocked at >2GHz
System Memory (RAM): 16Gb
Video Card (GPU): NVidia Quadro with 4Gb VRAM

This computer configuration will allow you to process a typical confocal microscope's image stack (2048x2048x150 voxels) in about 10 minutes.

### Credits
ObjectFinder is developed and maintained by Luca Della Santina at the University of California San Francisco. It builds on ideas initially developed in the [Wong Lab](http://wonglab.biostr.washington.edu/) at the University of Washington.
