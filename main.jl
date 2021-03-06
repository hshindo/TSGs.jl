using TSGs

config = Dict()
config["input_file"] = "data/nikujaga.txt"
config["output_file_rules"] = "rules.txt"
config["output_file_instances"] = "instances.txt"
config["nepochs"] = 10
config["nosplit"] = ["_I"]
config["stop_prior"] = (1, 1000) # prior counts of stop and non-stop

trainer = Trainer(config)
gibbs!(trainer)
output(trainer)
