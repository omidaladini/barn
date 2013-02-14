
#ifndef RSYNC_H
#define RSYNC_H

#include <string>
#include <vector>

const int PARTIAL_TRANSFER = 23;
const int PARTIAL_TRANSFER_DUE_VANISHED_SOURCE = 24;

const std::vector<std::string> get_rsync_candidates(std::string rsync_output);
const std::vector<std::string> choose_earliest_subset(std::vector<std::string> file_names);

#endif