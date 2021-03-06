function [opts, imdb] = model_setup(varargin)


% Copyright (C) 2015 Tsung-Yu Lin, Aruni RoyChowdhury, Subhransu Maji.
% All rights reserved.
%
% This file is part of the BCNN and is made available under
% the terms of the BSD license (see the COPYING file).

% setup ;

opts.seed = 1 ;
opts.batchSize = 128 ;
opts.numEpochs = 100;
opts.momentum = 0.9;
opts.learningRate = 0.001;
opts.numSubBatches = 1;
opts.keepAspect = true;
opts.useVal = false;
opts.fromScratch = false;
opts.useGpu = 1 ;
opts.regionBorder = 0.05 ;
opts.numDCNNWords = 64 ;
opts.numDSIFTWords = 256 ;
opts.numSamplesPerWord = 1000 ;
opts.printDatasetInfo = false ;
opts.excludeDifficult = true ;
opts.datasetSize = inf;
% opts.encoders = {struct('name', 'rcnn', 'opts', {})} ;
opts.encoders = {} ;
opts.dataset = 'cub' ;
opts.csiqDir = 'dataset\CSIQ database';
opts.liveDir = 'dataset\databaserelease2';
opts.tidDir = 'dataset\TID2013';
opts.cliveDir = 'dataset\ChallengeDB_release';
opts.mliveDir = 'dataset\LIVEmultidistortiondatabase\To_Release';
opts.ilsvrcDir = '/home/tsungyulin/dataset/ILSVRC2014/CLS-LOC/';
opts.ilsvrcDir_224 = '/home/tsungyulin/dataset/ILSVRC2014/CLS-LOC-224/';
opts.suffix = 'baseline' ;
opts.prefix = 'v1' ;
opts.model  = 'imagenet-vgg-m.mat';
opts.modela = 'imagenet-vgg-m.mat';
opts.modelb = [];
opts.layer  = 14;
opts.layera = [];
opts.layerb = [];
opts.imgScale = 1;
opts.bcnnLRinit = false;
opts.bcnnLayer = 14;
opts.rgbJitter = false;
opts.dataAugmentation = {'none', 'none', 'none'};
opts.cudnn = true;
opts.nonftbcnnDir = 'nonftbcnn';
opts.batchNormalization = false;
opts.cudnnWorkspaceLimit = 1024*1024*1204; 
opts.dataset_path = 'dataset\databaserelease2';

[opts, varargin] = vl_argparse(opts,varargin) ;

opts.expDir = sprintf('data/%s/%s-seed-%02d', opts.prefix, opts.dataset, opts.seed) ;
opts.nonftbcnnDir = fullfile(opts.expDir, opts.nonftbcnnDir);
opts.imdbDir = fullfile(opts.expDir, 'imdb') ;
opts.resultPath = fullfile(opts.expDir, sprintf('result-%s.mat', opts.suffix)) ;

opts = vl_argparse(opts,varargin) ;

if nargout <= 1, return ; end

% % Setup GPU if needed
% if opts.useGpu
%   gpuDevice(opts.useGpu) ;
% end

% -------------------------------------------------------------------------
%                                                            Setup encoders
% -------------------------------------------------------------------------

models = {} ;
modelPath = {};
for i = 1:numel(opts.encoders)
  if isstruct(opts.encoders{i})
    name = opts.encoders{i}.name ;
    opts.encoders{i}.path = fullfile(opts.expDir, [name '-encoder.mat']) ;
    opts.encoders{i}.codePath = fullfile(opts.expDir, [name '-codes.mat']) ;
    [md, mdpath] = get_cnn_model_from_encoder_opts(opts.encoders{i});
    models = horzcat(models, md) ;
    modelPath = horzcat(modelPath, mdpath);
%     models = horzcat(models, get_cnn_model_from_encoder_opts(opts.encoders{i})) ;
  else
    for j = 1:numel(opts.encoders{i})
      name = opts.encoders{i}{j}.name ;
      opts.encoders{i}{j}.path = fullfile(opts.expDir, [name '-encoder.mat']) ;
      opts.encoders{i}{j}.codePath = fullfile(opts.expDir, [name '-codes.mat']) ;
      [md, mdpath] = get_cnn_model_from_encoder_opts(opts.encoders{i}{j});      
      models = horzcat(models, md) ;
      modelPath = horzcat(modelPath, mdpath);
%       models = horzcat(models, get_cnn_model_from_encoder_opts(opts.encoders{i}{j})) ;
    end
  end
end

% -------------------------------------------------------------------------
%                                                       Download CNN models
% -------------------------------------------------------------------------

for i = 1:numel(models)
    if ~exist(modelPath{i})
        error(['cannot find model ', models{i}]) ;
    end
end

% -------------------------------------------------------------------------
%                                                              Load dataset
% -------------------------------------------------------------------------

vl_xmkdir(opts.expDir) ;
vl_xmkdir(opts.imdbDir) ;

switch opts.dataset
    case 'live'
        opts.dataset_path = opts.liveDir;
    case 'clive'
        opts.dataset_path = opts.cliveDir;
    case 'csiq'
        opts.dataset_path = opts.csiqDir;
    case 'tid'
        opts.dataset_path = opts.tidDir;
    case 'mlive'
        opts.dataset_path = opts.mliveDir;
    otherwise
        error('Unknown dataset %s', opts.dataset) ;
end


imdbPath = fullfile(opts.imdbDir, sprintf('imdb-seed-%d.mat', opts.seed)) ;
if exist(imdbPath)
  imdb = load(imdbPath) ;
  if(opts.rgbJitter)
      opts.pca = imdb_compute_pca(imdb, opts.expDir);
  end
  return ;
end

switch opts.dataset
    case 'live'
        imdb = getLiveDatabase_train(opts.liveDir);
    case 'clive'
        imdb = getCliveDatabase_train(opts.cliveDir);
    case 'csiq'
        imdb = getCsiqDatabase_train(opts.csiqDir);
    case 'tid'
        imdb = getTIDDatabase_train(opts.tidDir);
    case 'mlive'
        imdb = getMLIVEDatabase_train(opts.mliveDir);
    otherwise
        error('Unknown dataset %s', opts.dataset) ;
end

save(imdbPath, '-struct', 'imdb') ;

if(opts.rgbJitter)
   opts.pca = imdb_compute_pca(imdb, opts.expDir);
end

if opts.printDatasetInfo
  print_dataset_info(imdb) ;
end

% -------------------------------------------------------------------------
function [model, modelPath] = get_cnn_model_from_encoder_opts(encoder)
% -------------------------------------------------------------------------
p = find(strcmp('model', encoder.opts)) ;
if ~isempty(p)
  [~,m,e] = fileparts(encoder.opts{p+1}) ;
  model = {[m e]} ;
  modelPath = encoder.opts{p+1};
else
  model = {} ;
  modelPath = {};
end

% bilinear cnn models
p = find(strcmp('modela', encoder.opts)) ;
if ~isempty(p)
  [~,m,e] = fileparts(encoder.opts{p+1}) ;
  model = horzcat(model,{[m e]}) ;
  modelPath = horzcat(modelPath, encoder.opts{p+1});
end
p = find(strcmp('modelb', encoder.opts)) ;
if ~isempty(p) && ~isempty(encoder.opts{p+1})                
  [~,m,e] = fileparts(encoder.opts{p+1}) ;
  model = horzcat(model,{[m e]}) ;
  modelPath = horzcat(modelPath, encoder.opts{p+1});
end


