props <- read.csv('/Users/stevecotter/Downloads/alleghenycountymasterfile03022016.csv')
names(props) <- tolower(names(props))
wilkinsburg <- subset(props, municode %in% 866 ) #866 Code was identified from the property assessments website.