"""
Accumulate a specific type of statistic, for example 
by keeping constant size sufficient statistics 
(via `OnlineStat`, which conforms this interface), 
storing samples to a file, etc. 
See also [`recorders`](@ref).
"""
@informal recorder begin
    """
    $(TYPEDSIGNATURES)
    """
    record!(recorder, value) = @abstract 

    """
    $(TYPEDSIGNATURES)
    """
    combine(recorder1, recorder2) = @abstract
end


record!(recorder::OnlineStat, value) = fit!(recorder, value)
combine(recorder1::OnlineStat, recorder2::OnlineStat) = merge(recorder1, recorder2)


