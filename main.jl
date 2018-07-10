using TSGs

config = Dict()
config["train_file"] = "C:/Users/hshindo/Dropbox/corpus/wsj/wsj_22.mrg"
config["nepochs"] = 10

trainer = Trainer(config)
gibbs!(trainer)
output(trainer)
