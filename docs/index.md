
## ObjectFinder

![app_icon_big.png]({{site.baseurl}}/docs/app_icon_big.png)
##  Recognize 3D structures in MATLAB®


### What is ObjectFinder?
Symphony is a MATLAB program that allows recognition of small structures within three-dimensional image stacks. It is especially suited for neuroscience research, where it can be used to detect fluorescently-labeled synapses in image stacks acquired using confocal or super-resolution microscopes.

### Tuned for speed
ObjectFinder takes full advances of your computer's CPU by fully implementing multi-threaded search inside the 3D volume. On a computer with 8 cores this is an 8X fold speed bump!

### Seamlessly integrated with Bitplane Imaris®
ObjectFinder can display detected objects in Imaris® to take full advantage of its 3D rendering capabilities. You can visually add, remove or filter objects by visual inspection against the original 3D image.

### Create publication-quality plots
Using the "Plot" feature of ObjectFinder, you will be able to generate 


### How do I use ObjectFinder to find structures in my image?
The semi-automated object recognition process starts with creating a folder structure for your experiment with a base directory called after your experiment. Let's assume you'll call it "MyExperiment".
1. Create a subfolder called "MyExperiment/I" where you will place your original image stacks.
2. Start ObjectFinder from your MATLAB® Apps
3. Click the folder icon to select your experiment folder "MyExperiment"
4. Click "Load Images", the available images will be displayed as x-y projection and you will be asked to tell ObjectFinder which image contains the structures to recognize. Optionally, you can also specify which image contains a binary mask to limit the search.
5. Click "Search Objects" to start the automatic search of objects. Tip: enable the local cluster of cores in MATLAB® (bottom-left icon in your matlab main screen) to go at maximum speed taking full advantage of ObjectFinder's multithreaded search.
6. Click "Filter Objects" to remove candidate objects that are too small (only one plane on Z) and touching the optional mask's border.
7. If you have Bitplane Imaris® 7 installed, you can click on "Inspect 3D" in order to visually inspect and refine detected objects in three dimentions.
8. Click "Calc. Density" to finish the detection process and calculate information about object density in the volume.

### System Requirements
MATLAB R2016b+
Image Processing Toolbox
Parallel Computing Toolbox
BitPlane Imaris® 7.2.3

### Credits
ObjectFinder is developed by Luca Della Santina. Its built on ideas originally developed in the [Wong Lab](http://wonglab.biostr.washington.edu/) at the University of Washington.


