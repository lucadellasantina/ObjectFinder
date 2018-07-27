function Image = loadImage(FileName)
PathName = [pwd filesep 'I' filesep];
if ~isempty(FileName)
    ImInfo = imfinfo([PathName FileName]);
    Image = zeros(ImInfo(1).Height, ImInfo(1).Width, length(ImInfo));
    for j = 1:length(ImInfo)
        Image(:,:,j)=imread([PathName FileName], j);
    end
    Image = uint8(Image);
end
end