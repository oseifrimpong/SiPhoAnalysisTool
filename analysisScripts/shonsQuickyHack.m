function obj = shonsQuickyHack(obj)
offset = .586; %nm
for ii=309:1:546
    obj.dataset{1,ii}.peaks{1,1}.raw.peakWvl = obj.dataset{1,ii}.peaks{1,1}.raw.peakWvl +offset;
    obj.dataset{1,ii}.peaks{1,1}.fit.peakWvl = obj.dataset{1,ii}.peaks{1,1}.fit.peakWvl +offset;
end
end